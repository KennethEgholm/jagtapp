import Testing
@testable import JagtFokusCore

struct LocationAccuracyTests {
    @Test func noticeShowsOnlyWhenAllowedAndReduced() {
        #expect(LocationAccuracy.showsReducedNotice(access: .whenInUse, isReduced: true))
        #expect(LocationAccuracy.showsReducedNotice(access: .always, isReduced: true))
    }

    @Test func noNoticeWithFullAccuracy() {
        #expect(!LocationAccuracy.showsReducedNotice(access: .whenInUse, isReduced: false))
        #expect(!LocationAccuracy.showsReducedNotice(access: .always, isReduced: false))
    }

    /// Where there is no permission the system may still read "reduced". There is no puck to be wrong about.
    @Test func noNoticeWithoutPermission() {
        for access in [LocationAccuracy.Access.notDetermined, .restricted, .denied] {
            #expect(!LocationAccuracy.showsReducedNotice(access: access, isReduced: true))
        }
    }
}
