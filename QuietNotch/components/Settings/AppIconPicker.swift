//
//  AppIconPicker.swift
//  QuietNotch
//

import Defaults
import SwiftUI

struct AppIconPicker: View {
    @Default(.appIconChoice) private var choice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an app icon. Changes apply to the Dock and app switcher immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                ForEach(AppIconChoice.allCases, id: \.self) { option in
                    iconTile(option)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func iconTile(_ option: AppIconChoice) -> some View {
        let selected = choice == option
        VStack(spacing: 6) {
            Image(option.assetName)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                                      lineWidth: selected ? 3 : 1)
                )
            Text(option.rawValue)
                .font(.caption)
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            choice = option
        }
        .accessibilityLabel(option.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
