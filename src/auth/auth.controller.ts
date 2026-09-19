import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthService } from './auth.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterStaffDto } from './dto/register-staff.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@ApiTags('Authentification')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /**
   * Connexion universelle — Personnel médical et Admin uniquement.
   * Le patient n'a pas de compte en V1.
   */
  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Connexion (Email + Mot de passe) — Médecin, Infirmier, Sage-femme, Technicien, Admin',
    description: 'Retourne un token JWT et les informations de l\'utilisateur avec son rôle.',
  })
  @ApiBody({
    schema: {
      example: {
        email: 'medecin@polyclinique-arij.tn',
        password: 'MotDePasse123!',
      },
    },
  })
  @ApiResponse({ status: 200, description: 'Connexion réussie — Token JWT retourné' })
  @ApiResponse({ status: 401, description: 'Identifiants incorrects ou compte désactivé' })
  login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  /**
   * Auto-inscription d'un professionnel de santé
   * PUBLIC — L'employé s'enregistre lui-même mais son CIN DOIT être pré-autorisé par l'Admin.
   */
  @Public()
  @Post('register-staff')
  @ApiOperation({
    summary: 'Auto-inscription d\'un soignant (Médecin, Infirmier, Sage-femme, Technicien)',
    description:
      'Le travailleur s\'inscrit avec son CIN. Si son CIN n\'a pas été préalablement enregistré par l\'Administrateur dans le registre clinique, l\'accès est refusé (403 Forbidden).',
  })
  @ApiResponse({ status: 201, description: 'Compte soignant activé avec succès — Token JWT retourné' })
  @ApiResponse({ status: 403, description: 'CIN non accrédité par l\'administration de la clinique' })
  @ApiResponse({ status: 409, description: 'CIN ou Email déjà enregistré' })
  registerStaff(@Body() dto: RegisterStaffDto) {
    return this.authService.registerStaff(dto);
  }

  /**
   * Créer un compte pour un membre du personnel
   * ADMIN ONLY — L'Admin crée directement les comptes sans auto-inscription.
   */
  @Post('create-staff-account')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @ApiBearerAuth('bearer')
  @ApiOperation({
    summary: 'Créer un compte pour un membre du personnel (Admin uniquement)',
    description: 'L\'Admin crée directement le compte avec email + mot de passe temporaire. Le staff se connecte et change son mot de passe.',
  })
  @ApiResponse({ status: 201, description: 'Compte créé avec succès' })
  @ApiResponse({ status: 403, description: 'Accès refusé — Admin uniquement' })
  @ApiResponse({ status: 409, description: 'Email ou CIN déjà utilisé' })
  createStaffAccount(@Body() dto: any) {
    return this.authService.createStaffAccount(dto);
  }

  /**
   * Consulter son propre profil
   */
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @Get('profile')
  @ApiOperation({ summary: 'Consulter le profil de l\'utilisateur connecté' })
  getProfile(@CurrentUser('sub') userId: string) {
    return this.authService.getProfile(userId);
  }

  /**
   * Mettre à jour son propre profil (Photo avatar, téléphone, etc.)
   */
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  @ApiOperation({ summary: 'Mettre à jour son profil (Photo avatar, téléphone, nom)' })
  updateProfile(
    @CurrentUser('sub') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.authService.updateProfile(userId, dto);
  }

  /**
   * Changer son mot de passe
   */
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @Post('change-password')
  @ApiOperation({ summary: 'Modifier son mot de passe' })
  changePassword(
    @CurrentUser('sub') userId: string,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(userId, dto);
  }
}
