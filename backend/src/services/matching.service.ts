export interface MatchRequest {
  fromCampusId?: string;
  toCampusId?: string;
  date?: string;
  seats: number;
  startTime?: string;
  endTime?: string;
  maxBudget?: number;
}

export interface ScoreableRide {
  originCampusId: string;
  destinationCampusId: string;
  departureAt: Date;
  pricePerSeat: number;
  pickupRadiusKm: number;
  ratingAverage: number;
  completedRidesCount: number;
  cancellationCount: number;
}

export interface MatchScore {
  matchScore: number;
  scoreBreakdown: {
    route: number;
    time: number;
    pickup: number;
    budget: number;
    rating: number;
    reliability: number;
  };
}

const WEIGHTS: Record<string, number> = {
  route: 30,
  time: 25,
  pickup: 15,
  budget: 10,
  rating: 10,
  reliability: 10,
};

function timeOverlap(
  departure: Date,
  startTime?: string,
  endTime?: string,
): number {
  if (!startTime && !endTime) return 1;
  const depMins = departure.getUTCHours() * 60 + departure.getUTCMinutes();
  const start = startTime ? parseTime(startTime) : depMins;
  const end = endTime ? parseTime(endTime) : depMins;
  if (end < start) {
    return depMins >= start || depMins <= end ? 1 : 0;
  }
  if (depMins < start || depMins > end) return 0;
  if (end === start) return 1;
  return Math.max(0.2, 1 - Math.abs(depMins - (start + end) / 2) / ((end - start) / 2));
}

function parseTime(value: string): number {
  const [h, m] = value.split(':').map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

export function scoreRide(ride: ScoreableRide, request: MatchRequest): MatchScore {
  const route =
    ride.originCampusId === request.fromCampusId &&
    ride.destinationCampusId === request.toCampusId
      ? WEIGHTS.route
      : 0;

  const time = Math.round(WEIGHTS.time * timeOverlap(ride.departureAt, request.startTime, request.endTime));

  const pickup = Math.round(
    WEIGHTS.pickup * Math.min(1, (ride.pickupRadiusKm || 0) / 4),
  );

  let budget = WEIGHTS.budget;
  if (request.maxBudget !== undefined && request.maxBudget > 0) {
    budget =
      ride.pricePerSeat <= request.maxBudget
        ? WEIGHTS.budget
        : Math.round(WEIGHTS.budget * Math.max(0, 1 - (ride.pricePerSeat - request.maxBudget) / request.maxBudget));
  }

  const rating = ride.ratingAverage
    ? Math.round((WEIGHTS.rating * Math.min(5, ride.ratingAverage)) / 5)
    : 0;

  const total = ride.completedRidesCount + ride.cancellationCount;
  const reliability = total === 0
    ? WEIGHTS.reliability
    : Math.round(WEIGHTS.reliability * (ride.completedRidesCount / total));

  const matchScore = Math.max(0, Math.min(100, route + time + pickup + budget + rating + reliability));

  return {
    matchScore,
    scoreBreakdown: { route, time, pickup, budget, rating, reliability },
  };
}