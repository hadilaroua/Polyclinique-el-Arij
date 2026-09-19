import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: any = 'Une erreur interne est survenue sur le serveur';
    let error = 'Internal Server Error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res: any = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object' && res !== null) {
        message = res.message || res;
        error = res.error || error;
      }
    } else if (this.isInvalidMongoIdError(exception)) {
      status = HttpStatus.BAD_REQUEST;
      error = 'Bad Request';
      const value = this.extractInvalidId(exception);
      message = value
        ? `Identifiant invalide : « ${value} ». Un identifiant MongoDB doit contenir 24 caractères hexadécimaux.`
        : 'Identifiant MongoDB invalide';
    } else if (exception instanceof Error) {
      this.logger.error(`Erreur inattendue : ${exception.message}`, exception.stack);
    }

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      error,
      message,
    });
  }

  private isInvalidMongoIdError(exception: unknown): boolean {
    if (!(exception instanceof Error)) {
      return false;
    }
    return (
      exception.name === 'CastError' ||
      exception.name === 'BSONError' ||
      exception.name === 'BSONTypeError'
    );
  }

  private extractInvalidId(exception: unknown): string | undefined {
    if (typeof exception === 'object' && exception !== null && 'value' in exception) {
      const value = (exception as { value?: unknown }).value;
      if (value !== undefined && value !== null) {
        return String(value);
      }
    }
    return undefined;
  }
}
