import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/user.dart';
import 'firebase_event_service.dart';
import 'firebase_user_service.dart';

class FirebaseDemoDataService {
  static const _uuid = Uuid();

  static Future<void> initializeDemoData() async {
    await _createDemoUsers();
    await _createDemoEvents();
  }

  static Future<void> _createDemoUsers() async {
    // Check if users already exist
    final existingUsers = await FirebaseUserService.getAllUsers();
    if (existingUsers.isNotEmpty) return;

    // Create demo participant
    final participant = User(
      id: 'demo_participant',
      email: 'john.doe@baust.edu',
      name: 'John Doe',
      universityId: '2021-1-60-123',
      type: UserType.participant,
      createdAt: DateTime.now(),
    );

    // Create demo organizer
    final organizer = User(
      id: 'demo_organizer',
      email: 'sarah.johnson@baust.edu',
      name: 'Dr. Sarah Johnson',
      universityId: 'FAC-2020-001',
      type: UserType.organizer,
      createdAt: DateTime.now(),
    );

    await FirebaseUserService.createUser(participant);
    await FirebaseUserService.createUser(organizer);
  }

  static Future<void> _createDemoEvents() async {
    // Check if events already exist
    final existingEvents = await FirebaseEventService.getAllEvents();
    if (existingEvents.isNotEmpty) return;

    final now = DateTime.now();
    final organizerId = 'demo_organizer';

    final demoEvents = [
      Event(
        id: _uuid.v4(),
        title: 'Tech Innovation Summit 2024',
        description: 'Join us for an exciting day of technology discussions, networking, and innovation showcase. This summit brings together industry leaders, researchers, and students to explore the latest trends in technology.',
        date: now.add(const Duration(days: 5)),
        time: '10:00 AM',
        location: 'Main Auditorium',
        category: 'Seminars',
        organizerId: organizerId,
        participants: ['demo_participant'],
        status: EventStatus.active,
        maxParticipants: 200,
      ),
      Event(
        id: _uuid.v4(),
        title: 'Cultural Night 2024',
        description: 'A spectacular evening of music, dance, and cultural performances from around the world. Experience the rich diversity of our university community through art and entertainment.',
        date: now.add(const Duration(days: 10)),
        time: '7:00 PM',
        location: 'Cultural Center',
        category: 'Cultural',
        organizerId: organizerId,
        participants: ['demo_participant'],
        status: EventStatus.published,
        maxParticipants: 150,
      ),
      Event(
        id: _uuid.v4(),
        title: 'Coding Workshop: Advanced Flutter',
        description: 'Learn advanced Flutter development techniques, state management, and best practices. This hands-on workshop is perfect for developers looking to enhance their mobile app development skills.',
        date: now.add(const Duration(days: 15)),
        time: '2:00 PM',
        location: 'Computer Lab 3',
        category: 'Workshops',
        organizerId: organizerId,
        participants: [],
        status: EventStatus.published,
        maxParticipants: 30,
      ),
      Event(
        id: _uuid.v4(),
        title: 'Hackathon 2024',
        description: '48-hour coding competition where teams will build innovative solutions to real-world problems. Prizes, mentorship, and networking opportunities await!',
        date: now.add(const Duration(days: 20)),
        time: '9:00 AM',
        location: 'Engineering Building',
        category: 'Competitions',
        organizerId: organizerId,
        participants: [],
        status: EventStatus.published,
        maxParticipants: 100,
      ),
      Event(
        id: _uuid.v4(),
        title: 'AI and Machine Learning Conference',
        description: 'Explore the latest developments in artificial intelligence and machine learning. Featuring keynote speakers, technical sessions, and hands-on demonstrations.',
        date: now.add(const Duration(days: 25)),
        time: '9:00 AM',
        location: 'Conference Hall',
        category: 'Seminars',
        organizerId: organizerId,
        participants: [],
        status: EventStatus.draft,
        maxParticipants: 80,
      ),
      Event(
        id: _uuid.v4(),
        title: 'Sports Tournament Finals',
        description: 'Witness the culmination of our annual sports tournament with exciting matches in basketball, football, and volleyball. Cheer for your favorite teams!',
        date: now.add(const Duration(days: 30)),
        time: '3:00 PM',
        location: 'Sports Complex',
        category: 'Competitions',
        organizerId: organizerId,
        participants: [],
        status: EventStatus.published,
        maxParticipants: 500,
      ),
    ];

    for (final event in demoEvents) {
      await FirebaseEventService.createEvent(event);
    }
  }
}
