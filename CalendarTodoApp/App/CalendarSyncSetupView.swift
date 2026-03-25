import CalendarTodoCore
import SwiftUI

struct CalendarSyncSetupView: View {
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 아이콘
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accent)
                .padding(.bottom, 20)

            // 제목
            Text(L10n.calendarSyncTitle)
                .font(AppTheme.displayFont)
                .padding(.bottom, 8)

            // 설명
            Text(L10n.calendarSyncDescription)
                .font(AppTheme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // 연동하기 버튼
            Button {
                Task {
                    let granted = await EventKitService.shared.requestAccess()
                    if granted {
                        print("[Calendar] Access granted")
                    }
                    onComplete()
                }
            } label: {
                Text(L10n.syncAppleCalendar)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)

            // 나중에 버튼
            Button {
                onComplete()
            } label: {
                Text(L10n.maybeLater)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
    }
}
