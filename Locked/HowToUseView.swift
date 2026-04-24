//
//  HowToUseView.swift
//  Locked
//
//  Created by Jacob Scheff on 4/19/26.
//

import SwiftUI

struct HowToUseView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - How It Works Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "How It Works", icon: "info.circle.fill", color: .blue)
                        
                        InfoRow(
                            icon: "key.fill",
                            iconColor: .orange,
                            title: "Keys",
                            description: "Keys determine how much screentime usage you have left. As your keys decrease, the apps available slowly decrease. The earlier you complete your assignments, the more Keys you get."
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "star.fill",
                            iconColor: .purple,
                            title: "Karma",
                            description: "Karma is measured by how consistently and early you complete your assignments. Lower karma means your most-used apps disappear quicker. Higher karma makes your most-used apps disappear last."
                        )
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    
                    // MARK: - Siri Shortcuts Integration
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Siri Shortcuts Setup", icon: "bolt.fill", color: .yellow)
                        
                        Text("To track screentime, you must integrate Locked into your Shortcuts app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // App Open Setup
                        StepCard(
                            stepNumber: 1,
                            title: "On App Open",
                            instructions: [
                                "Open **Shortcuts** > **Automation**.",
                                "Create a new automation and select **App**.",
                                "Choose **Is Opened** and **Run Immediately** (disable *Notify When Run* for a seamless experience).",
                                "Select which apps you want to be part of the Locked experience.",
                                "In the shortcut, add the **\"Get Current App\"** block.",
                                "Next, add the **\"On App Open\"** block provided by the Locked app.",
                                "Set the *App Name* parameter to the *Current App* variable.",
                                "Add an **\"If\"** statement block directly below it.",
                                "Set the condition: **If** *On App Open Result* is **True**.",
                                "Inside the If statement, add the **\"Go to Home Screen\"** action. This ensures you get kicked out if an app is locked!"
                            ]
                        )
                        
                        // App Close Setup
                        StepCard(
                            stepNumber: 2,
                            title: "On App Close",
                            instructions: [
                                "Go back to **Automation** and create a new **App** automation.",
                                "Choose **Is Closed** and **Run Immediately** (disable *Notify When Run*).",
                                "Select the exact same apps you chose earlier.",
                                "In the shortcut, add the **\"On App Close\"** block provided by Locked.",
                                "No parameters or current app blocks are needed here."
                            ]
                        )
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    
                    // MARK: - Extra Settings
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "App Ranking", icon: "slider.horizontal.3", color: .indigo)
                        
                        (
                            Text("If you ever want to override the ranking of your app popularities, you can do so manually by clicking on the ") +
                            Text(Image(systemName: "slider.horizontal.3")).foregroundStyle(.indigo) +
                            Text(" button in the App Rankings section.")
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StepCard: View {
    let stepNumber: Int
    let title: String
    let instructions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("\(stepNumber)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.indigo)
                    )
                
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(try! AttributedString(markdown: instruction))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding()
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
