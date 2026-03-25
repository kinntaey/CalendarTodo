import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.accentGradient)
                    .padding(.top, 60)

                Text(L10n.welcomeTitle)
                    .font(AppTheme.displayFont)

                Text(L10n.welcomeSubtitle)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)

            Spacer()

            // Time format selection
            VStack(spacing: 16) {
                Text(L10n.timeFormatTitle)
                    .font(AppTheme.titleFont)

                Text(L10n.timeFormatDescription)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(AppSettings.TimeFormat.allCases, id: \.self) { format in
                        OptionCard(
                            title: format.label,
                            subtitle: format.example,
                            isSelected: settings.timeFormat == format
                        ) {
                            settings.timeFormat = format
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Start button
            Button {
                settings.hasCompletedOnboarding = true
            } label: {
                Text(L10n.getStarted)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.accentGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                    .cardShadow()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }
}

private struct OptionCard: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .fill(isSelected ? AppTheme.accent.opacity(0.08) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
