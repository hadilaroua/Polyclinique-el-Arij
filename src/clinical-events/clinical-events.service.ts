import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { google } from 'googleapis';
import { NotificationsService } from '../notifications/notifications.service';
import { PatientsService } from '../patients/patients.service';
import { CheckAvailabilityDto, CreateClinicalEventDto, UpdateClinicalEventDto } from './dto/clinical-event.dto';
import { ClinicalEvent, ClinicalEventDocument } from './schemas/clinical-event.schema';

@Injectable()
export class ClinicalEventsService {
  private isGoogleConnected = true;
  private googleConnectedEmail = process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL || 'hadil.aroua@esprit.tn';

  constructor(
    @InjectModel(ClinicalEvent.name)
    private readonly clinicalEventModel: Model<ClinicalEventDocument>,
    private readonly notificationsService: NotificationsService,
    private readonly patientsService: PatientsService,
  ) {}

  private getGoogleCalendarClient() {
    const apiKey = process.env.GOOGLE_API_KEY;
    const clientEmail = process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL;
    const rawKey = process.env.GOOGLE_PRIVATE_KEY;
    const privateKey = rawKey ? rawKey.replace(/\\n/g, '\n') : '';

    try {
      if (clientEmail && privateKey && privateKey.trim() !== '') {
        const auth = new google.auth.JWT({
          email: clientEmail,
          key: privateKey,
          scopes: ['https://www.googleapis.com/auth/calendar'],
        });
        return google.calendar({ version: 'v3', auth });
      }

      if (apiKey && apiKey.trim() !== '') {
        return google.calendar({ version: 'v3', auth: apiKey });
      }
    } catch (err) {
      console.warn('[GoogleCalendar] Échec d\'initialisation Client Google:', err);
    }

    return null;
  }

  private async syncToGoogleCalendar(event: any, patName: string, docName: string): Promise<string> {
    const calendar = this.getGoogleCalendarClient();
    const calendarId = process.env.GOOGLE_CALENDAR_ID || 'primary';

    const startIso = `${event.date}T${event.startTime}:00`;
    const endIso = `${event.date}T${event.endTime}:00`;

    const eventResource = {
      summary: `[ARIJ] ${event.procedureTitle} — ${patName}`,
      location: event.roomId,
      description: `Intervention programmée à la Polyclinique El Arij.\nPatient: ${patName}\nMédecin: ${docName}\nSalle/Bloc: ${event.roomId}\nNotes: ${event.notes || 'Aucune'}`,
      start: { dateTime: new Date(startIso).toISOString(), timeZone: 'Africa/Tunis' },
      end: { dateTime: new Date(endIso).toISOString(), timeZone: 'Africa/Tunis' },
    };

    if (calendar) {
      try {
        if (event.googleCalendarEventId && !event.googleCalendarEventId.startsWith('gcal_sim_')) {
          const updated = await calendar.events.update({
            calendarId,
            eventId: event.googleCalendarEventId,
            requestBody: eventResource,
          });
          return updated.data.id || event.googleCalendarEventId;
        } else {
          const created = await calendar.events.insert({
            calendarId,
            requestBody: eventResource,
          });
          return created.data.id || `gcal_live_${Date.now()}`;
        }
      } catch (error) {
        console.error('[GoogleCalendar API Error] Sync API Google Cloud:', error);
      }
    }

    return event.googleCalendarEventId || `gcal_sim_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  }

  private parseMinutes(timeStr: string): number {
    if (!timeStr) return 0;
    const parts = timeStr.trim().split(':');
    if (parts.length < 2) return 0;
    const hours = parseInt(parts[0], 10) || 0;
    const minutes = parseInt(parts[1], 10) || 0;
    return hours * 60 + minutes;
  }

  async checkAvailability(dto: CheckAvailabilityDto): Promise<{ available: boolean; conflictingEvent?: any }> {
    const { roomId, date, startTime, endTime, excludeEventId } = dto;
    const startMin = this.parseMinutes(startTime);
    const endMin = this.parseMinutes(endTime);

    const query: any = {
      roomId: roomId.trim(),
      date: date.trim(),
      status: 'SCHEDULED',
    };

    if (excludeEventId) {
      query._id = { $ne: excludeEventId };
    }

    const existingEvents = await this.clinicalEventModel
      .find(query)
      .populate('patientId', 'firstName lastName')
      .populate('doctorId', 'firstName lastName')
      .exec();

    for (const ev of existingEvents) {
      const evStart = this.parseMinutes(ev.startTime);
      const evEnd = this.parseMinutes(ev.endTime);

      if (startMin < evEnd && endMin > evStart) {
        return {
          available: false,
          conflictingEvent: {
            id: ev._id.toString(),
            procedureTitle: ev.procedureTitle,
            startTime: ev.startTime,
            endTime: ev.endTime,
            patientName: (ev.patientId as any) ? `${(ev.patientId as any).firstName} ${(ev.patientId as any).lastName}` : 'Patient',
            doctorName: (ev.doctorId as any) ? `Dr ${(ev.doctorId as any).lastName}` : 'Médecin',
          },
        };
      }
    }

    return { available: true };
  }

  async create(dto: CreateClinicalEventDto): Promise<ClinicalEvent> {
    // 1. Room Availability Check
    const availability = await this.checkAvailability({
      roomId: dto.roomId,
      date: dto.date,
      startTime: dto.startTime,
      endTime: dto.endTime,
    });

    if (!availability.available) {
      throw new ConflictException(
        `Salle indisponible : La salle "${dto.roomId}" est déjà réservée le ${dto.date} de ${availability.conflictingEvent?.startTime} à ${availability.conflictingEvent?.endTime} (${availability.conflictingEvent?.procedureTitle} — ${availability.conflictingEvent?.patientName}).`,
      );
    }

    // 2. Derive procedure title if not explicit
    let title = dto.procedureTitle;
    if (!title || title.trim() === '') {
      switch (dto.procedureType) {
        case 'CESAREAN':
          title = 'Césarienne';
          break;
        case 'SURGERY':
          title = 'Intervention Chirurgicale';
          break;
        case 'DELIVERY':
          title = 'Accouchement';
          break;
        case 'PROCEDURE':
          title = 'Procédure médicale';
          break;
        default:
          title = 'Intervention programmée';
      }
    }

    // 3. Resolve assigned team
    const assignedStaffSet = new Set<string>(dto.assignedStaffIds ?? []);
    try {
      const pat = await this.patientsService.findById(dto.patientId);
      if (pat) {
        if (pat.assignedNurseId) {
          const nId = typeof pat.assignedNurseId === 'object' ? (pat.assignedNurseId as any)._id?.toString() : (pat.assignedNurseId as any)?.toString();
          if (nId) assignedStaffSet.add(nId);
        }
        if (pat.assignedMidwifeId) {
          const mId = typeof pat.assignedMidwifeId === 'object' ? (pat.assignedMidwifeId as any)._id?.toString() : (pat.assignedMidwifeId as any)?.toString();
          if (mId) assignedStaffSet.add(mId);
        }
      }
    } catch (_) {}

    // 4. Create Event Document
    const googleEventId = `gcal_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const createdEvent = new this.clinicalEventModel({
      ...dto,
      procedureTitle: title,
      assignedStaffIds: Array.from(assignedStaffSet),
      googleCalendarEventId: googleEventId,
      status: 'SCHEDULED',
    });

    const saved = await createdEvent.save();

    // 5. Trigger Targeted Notifications & Google Calendar Sync
    const populated = await this.findById(saved._id.toString());
    const patName = (populated.patientId as any)
      ? `${(populated.patientId as any).firstName} ${(populated.patientId as any).lastName}`
      : 'Patient';
    const docName = (populated.doctorId as any)
      ? `Dr. ${(populated.doctorId as any).lastName}`
      : 'Médecin Traitant';

    const liveGcalId = await this.syncToGoogleCalendar(saved, patName, docName);
    if (liveGcalId !== googleEventId) {
      await this.clinicalEventModel.findByIdAndUpdate(saved._id, { googleCalendarEventId: liveGcalId });
      populated.googleCalendarEventId = liveGcalId;
    }

    for (const staffId of saved.assignedStaffIds) {
      await this.notificationsService.create({
        recipientUserId: staffId.toString(),
        title: `Intervention programmée : ${title}`,
        body: `${title} pour ${patName} le ${saved.date} à ${saved.startTime} (${saved.roomId}). Vous êtes concerné(e) par cette intervention.`,
        type: 'APPOINTMENT',
        relatedId: saved._id.toString(),
      });
    }

    return populated;
  }

  async findAll(date?: string, doctorId?: string, patientId?: string, roomId?: string, status?: string): Promise<ClinicalEvent[]> {
    const query: any = {};
    if (date) query.date = date;
    if (doctorId) query.doctorId = doctorId;
    if (patientId) query.patientId = patientId;
    if (roomId) query.roomId = roomId;
    if (status) query.status = status;

    return this.clinicalEventModel
      .find(query)
      .populate('patientId')
      .populate('doctorId')
      .populate('assignedStaffIds')
      .sort({ date: 1, startTime: 1 })
      .exec();
  }

  async findById(id: string): Promise<ClinicalEvent> {
    const event = await this.clinicalEventModel
      .findById(id)
      .populate('patientId')
      .populate('doctorId')
      .populate('assignedStaffIds')
      .exec();

    if (!event) {
      throw new NotFoundException(`Événement clinique #${id} non trouvé`);
    }
    return event;
  }

  async update(id: string, dto: UpdateClinicalEventDto): Promise<ClinicalEvent> {
    const existing = await this.clinicalEventModel.findById(id).exec();
    if (!existing) {
      throw new NotFoundException(`Événement clinique #${id} non trouvé`);
    }

    // Re-verify room availability if date, time or room changed
    const targetRoom = dto.roomId ?? existing.roomId;
    const targetDate = dto.date ?? existing.date;
    const targetStart = dto.startTime ?? existing.startTime;
    const targetEnd = dto.endTime ?? existing.endTime;

    if (dto.roomId || dto.date || dto.startTime || dto.endTime) {
      const avail = await this.checkAvailability({
        roomId: targetRoom,
        date: targetDate,
        startTime: targetStart,
        endTime: targetEnd,
        excludeEventId: id,
      });

      if (!avail.available) {
        throw new ConflictException(
          `Conflit de réservation : La salle "${targetRoom}" est occupée de ${avail.conflictingEvent?.startTime} à ${avail.conflictingEvent?.endTime} par ${avail.conflictingEvent?.patientName}.`,
        );
      }
    }

    const updated = await this.clinicalEventModel
      .findByIdAndUpdate(id, { $set: dto }, { new: true })
      .populate('patientId')
      .populate('doctorId')
      .populate('assignedStaffIds')
      .exec();

    if (!updated) {
      throw new NotFoundException(`Événement clinique #${id} introuvable`);
    }

    // Notify assigned team of modification
    const patName = (updated.patientId as any)
      ? `${(updated.patientId as any).firstName} ${(updated.patientId as any).lastName}`
      : 'Patient';

    for (const staffId of updated.assignedStaffIds) {
      await this.notificationsService.create({
        recipientUserId: staffId.toString(),
        title: `Modification d'intervention : ${updated.procedureTitle}`,
        body: `L'intervention pour ${patName} a été modifiée : ${updated.date} de ${updated.startTime} à ${updated.endTime} (${updated.roomId}).`,
        type: 'APPOINTMENT',
        relatedId: updated._id.toString(),
      });
    }

    return updated;
  }

  async cancel(id: string): Promise<ClinicalEvent> {
    const updated = await this.clinicalEventModel
      .findByIdAndUpdate(id, { $set: { status: 'CANCELLED' } }, { new: true })
      .populate('patientId')
      .populate('doctorId')
      .populate('assignedStaffIds')
      .exec();

    if (!updated) {
      throw new NotFoundException(`Événement clinique #${id} introuvable`);
    }

    // Notify assigned team of cancellation & free room
    const patName = (updated.patientId as any)
      ? `${(updated.patientId as any).firstName} ${(updated.patientId as any).lastName}`
      : 'Patient';

    for (const staffId of updated.assignedStaffIds) {
      await this.notificationsService.create({
        recipientUserId: staffId.toString(),
        title: `Annulation d'intervention : ${updated.procedureTitle}`,
        body: `L'intervention de ${patName} prévue le ${updated.date} à ${updated.startTime} (${updated.roomId}) a été annulée. La salle est libérée.`,
        type: 'APPOINTMENT',
        relatedId: updated._id.toString(),
      });
    }

    return updated;
  }

  // --- Google Calendar Sync Handlers ---
  getGoogleSyncStatus(): { isConnected: boolean; accountEmail?: string } {
    return {
      isConnected: this.isGoogleConnected,
      accountEmail: this.isGoogleConnected ? (this.googleConnectedEmail || 'hadil.aroua@esprit.tn') : undefined,
    };
  }

  connectGoogleSync(email?: string): { success: boolean; accountEmail: string } {
    this.isGoogleConnected = true;
    this.googleConnectedEmail = email || 'hadil.aroua@esprit.tn';
    return { success: true, accountEmail: this.googleConnectedEmail };
  }

  disconnectGoogleSync(): { success: boolean } {
    this.isGoogleConnected = false;
    this.googleConnectedEmail = '';
    return { success: true };
  }
}
