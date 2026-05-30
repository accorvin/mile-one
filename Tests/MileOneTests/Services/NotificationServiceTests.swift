import Testing
import UserNotifications
@testable import MileOne

struct NotificationServiceTests {

    @Test func scheduleRemindersForRunDays() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)

        // Schedule for Mon (2), Wed (4), Fri (6) at 7:00 AM
        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )

        #expect(mockCenter.pendingRequests.count == 3, "Should schedule one reminder per run day")

        // Verify each reminder is for the correct weekday
        let weekdays = mockCenter.pendingRequests.compactMap { request -> Int? in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return nil }
            return trigger.dateComponents.weekday
        }
        #expect(Set(weekdays) == Set([2, 4, 6]))
    }

    @Test func remindersReplaceExistingOnReschedule() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)

        // Schedule initial reminders
        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )
        #expect(mockCenter.pendingRequests.count == 3)

        // Reschedule for different days
        try await service.scheduleRunReminders(
            runDays: [3, 5],
            time: DateComponents(hour: 8, minute: 30)
        )

        // Old reminders should be removed, only new ones remain
        #expect(mockCenter.pendingRequests.count == 2, "Rescheduling must remove old reminders")
    }

    @Test func permissionDeniedSkipsScheduling() async throws {
        let mockCenter = MockNotificationCenter()
        mockCenter.authorizationGranted = false
        let service = NotificationService(center: mockCenter)

        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )

        #expect(mockCenter.pendingRequests.count == 0,
                "Must not schedule if permission denied")
    }

    @Test func reminderContentIsMotivational() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)

        try await service.scheduleRunReminders(
            runDays: [2],
            time: DateComponents(hour: 7, minute: 0)
        )

        let content = mockCenter.pendingRequests.first?.content
        #expect(content?.title.isEmpty == false, "Reminder must have a title")
        #expect(content?.body.isEmpty == false, "Reminder must have a body")
        #expect(content?.sound != nil, "Reminder must have a sound")
    }
}
