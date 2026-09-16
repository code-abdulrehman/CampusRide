import { randomUUID } from 'node:crypto';

export interface RealtimeEvent<T = unknown> {
  type: string;
  eventId: string;
  occurredAt: string;
  entityVersion?: number;
  data: T;
}

export function buildEvent<T>(type: string, data: T, entityVersion?: number): RealtimeEvent<T> {
  return {
    type,
    eventId: randomUUID(),
    occurredAt: new Date().toISOString(),
    ...(entityVersion !== undefined ? { entityVersion } : {}),
    data,
  };
}

export const EventTypes = {
  SystemConnected: 'system.connected',
  SystemResyncRequired: 'system.resync_required',
  RideCreated: 'ride.created',
  RideUpdated: 'ride.updated',
  RideCancelled: 'ride.cancelled',
  RideSeatsUpdated: 'ride.seats.updated',
  RideStarted: 'ride.started',
  RideCompleted: 'ride.completed',
  RideRequestCreated: 'ride_request.created',
  RideRequestUpdated: 'ride_request.updated',
  RideRequestCancelled: 'ride_request.cancelled',
  BookingRequested: 'booking.requested',
  BookingAccepted: 'booking.accepted',
  BookingRejected: 'booking.rejected',
  BookingCancelled: 'booking.cancelled',
  BookingCheckedIn: 'booking.checked_in',
  BookingNoShow: 'booking.no_show',
  NotificationCreated: 'notification.created',
  VerificationUpdated: 'verification.updated',
  AccountStatusUpdated: 'account.status.updated',
  LocationUpdated: 'location.updated',
ReportCreated: 'report.created',
} as const;

export function userChannel(userId: string): string {
  return `user:${userId}`;
}

export function rideChannel(rideId: string): string {
  return `ride:${rideId}`;
}

export function routeChannel(fromCampusId: string, toCampusId: string, date: string): string {
  return `route:${fromCampusId}:${toCampusId}:${date}`;
}

export const adminChannel = 'admin';

export function channelDate(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toISOString().slice(0, 10);
}