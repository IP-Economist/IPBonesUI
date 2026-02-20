//
//  IPBones.swift
//  ipbones
//  Created by IP-Economist 2026
//

import SwiftUI
import Charts
import IPBones

// MARK: - Main View
struct ContentView: View {
    var body: some View {
        VStack {
            Text("IPBones Tools")
            NavigationView {
                List {
                    NavigationLink("Value Evaluation", destination: ValueView())
                    NavigationLink("Royalty Calculation", destination: RoyaltyView())
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200)
                
                Text("Select a tool from the sidebar")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("IPBones Tools")
    }
}

// MARK: - Value Evaluation View
struct ValueView: View {
    // Inputs
    @State private var costString = ""
    @State private var addedCoefficientString = ""
    @State private var dataPoints: [AnalysisData] = []
    
    // Results & errors
    @State private var resultValue: Double?
    @State private var errorMessage: String?
    @State private var regressionCoefs: (const: Double, coef1: Double)?
    
    // UI state
    @State private var showResult = false
    @State private var showChart = false
    @State private var hoverButton = false
    
    // For dynamic row addition
    @State private var newName = ""
    @State private var newValue = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: Cost Input
                VStack(alignment: .leading) {
                    Text("Cost (Int)")
                        .font(.headline)
                    TextField("e.g. 1000", text: $costString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // MARK: Evaluation Mode Picker
                DisclosureGroup("Use fixed added coefficient?") {
                    VStack(alignment: .leading) {
                        Text("Added Coefficient (optional)")
                            .font(.subheadline)
                        TextField("e.g. 500", text: $addedCoefficientString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 8)
                }
                .disclosureGroupStyle(CustomDisclosureStyle())
                
                DisclosureGroup("Or use regression data") {
                    VStack(alignment: .leading) {
                        // List of data points using enumerated() and id: \.element.id
                        ForEach(Array(dataPoints.enumerated()), id: \.element.id) { index, point in
                            HStack {
                                TextField("Name", text: bindingForName(at: index))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Value", text: bindingForValue(at: index))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 100)
                                
                                Button(action: { removeDataPoint(at: index) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onTapGesture { removeDataPoint(at: index) }
                            }
                        }
                        
                        // Add new data row
                        HStack {
                            TextField("Name", text: $newName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Value", text: $newValue)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                            
                            Button(action: addDataPoint) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture(perform: addDataPoint)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disclosureGroupStyle(CustomDisclosureStyle())
                
                // MARK: Compute Button
                HStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hoverButton ? Color.blue.opacity(0.8) : Color.blue)
                        .frame(width: 150, height: 44)
                        .overlay(
                            Text("Compute Value")
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                        .scaleEffect(hoverButton ? 1.05 : 1.0)
                        .shadow(color: .blue.opacity(0.3), radius: hoverButton ? 8 : 4)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoverButton = hovering
                            }
                        }
                        .onTapGesture(perform: computeValue)
                    
                    Spacer()
                }
                
                // MARK: Result Card (with transition)
                if showResult {
                    resultCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // MARK: Chart (with transition)
                if showChart, let coefs = regressionCoefs, dataPoints.count >= 2 {
                    regressionChart(with: coefs)
                        .frame(height: 250)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding()
        }
        .background {
            #if os(macOS)
            LinearGradient(
                gradient: Gradient(colors: [Color(NSColor.windowBackgroundColor), Color.gray.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            #else
            LinearGradient(
                gradient: Gradient(
                    colors: [Color.gray, Color.gray.opacity(0.1)]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            #endif
        }
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    errorMessage = nil
                }
            )
        }
    }
    
    // MARK: - Result Card
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Result")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let result = resultValue {
                Text("Method IP‑Economist: \(result, specifier: "%.2f")")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
            
            if let coefs = regressionCoefs {
                Divider()
                Text("Regression line: Y = \(coefs.const, specifier: "%.2f") + \(coefs.coef1, specifier: "%.2f")·X")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
            #if os(macOS)
                .fill(Color(NSColor.controlBackgroundColor))
            #else
                .fill(Color.gray)
            #endif
                .shadow(color: .gray.opacity(0.4), radius: 6, x: 0, y: 3)
                
        }
    }
    
    // MARK: - Regression Chart
    private func regressionChart(with coefs: (const: Double, coef1: Double)) -> some View {
        let indices = Array(0..<dataPoints.count)
        let minX = indices.first.map { Double($0) } ?? 0
        let maxX = indices.last.map { Double($0) } ?? 0
        
        return Chart {
            // Data points
            ForEach(Array(dataPoints.enumerated()), id: \.element.id) { index, point in
                PointMark(
                    x: .value("Index", index),
                    y: .value("Value", doubleValue(from: point.value))
                )
                .foregroundStyle(Color.blue)
                .symbolSize(100)
            }
            
            // Regression line
            LineMark(
                x: .value("Index", minX),
                y: .value("Value", coefs.const + coefs.coef1 * minX)
            )
            LineMark(
                x: .value("Index", maxX),
                y: .value("Value", coefs.const + coefs.coef1 * maxX)
            )
            .foregroundStyle(Color.red)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
        .chartYAxisLabel("Value")
        .chartXAxisLabel("Data Index")
        .padding()
        .background{
            RoundedRectangle(cornerRadius: 12)
                #if os(macOS)
                .fill(Color(NSColor.controlBackgroundColor))
                #else
                .fill(Color.gray)
                #endif
                .shadow(color: .gray.opacity(0.3), radius: 4)
        }
    }
    
    // MARK: - Helpers
    
    private func doubleValue(from number: Number) -> Double {
        if let d = number as? Double { return d }
        if let i = number as? Int { return Double(i) }
        return 0
    }
    
    private func bindingForName(at index: Int) -> Binding<String> {
        Binding(
            get: { dataPoints[index].name },
            set: { dataPoints[index].name = $0 }
        )
    }
    
    private func bindingForValue(at index: Int) -> Binding<String> {
        Binding(
            get: { String(describing: dataPoints[index].value) },
            set: { newValue in
                if let intVal = Int(newValue) {
                    dataPoints[index].value = intVal
                } else if let doubleVal = Double(newValue) {
                    dataPoints[index].value = doubleVal
                }
                // else ignore
            }
        )
    }
    
    private func addDataPoint() {
        guard !newName.isEmpty, !newValue.isEmpty else { return }
        if let intVal = Int(newValue) {
            dataPoints.append(AnalysisData(name: newName, value: intVal))
        } else if let doubleVal = Double(newValue) {
            dataPoints.append(AnalysisData(name: newName, value: doubleVal))
        }
        newName = ""
        newValue = ""
    }
    
    private func removeDataPoint(at index: Int) {
        dataPoints.remove(at: index)
        // Hide chart if insufficient data
        if dataPoints.count < 2 {
            withAnimation { showChart = false }
        }
    }
    
    private func computeValue() {
        // Reset previous state
        resultValue = nil
        regressionCoefs = nil
        errorMessage = nil
        
        guard let cost = Int(costString) else {
            errorMessage = "Please enter a valid integer cost."
            return
        }
        
        var valueObject: IPBones_Value
        
        if let added = Int(addedCoefficientString), addedCoefficientString != "" {
            // Use added coefficient mode
            valueObject = IPBones_Value(cost: cost, addedCoefficient: added)
            withAnimation { showChart = false }
        } else if !dataPoints.isEmpty {
            // Use regression data
            valueObject = IPBones_Value(cost: cost, data: dataPoints)
        } else {
            errorMessage = "Either provide an added coefficient or at least one data point."
            return
        }
        
        do {
            let result = try valueObject.method_ipEconomist()
            resultValue = result
            
            // If we have data, compute regression coefficients for chart using Econometrics_Engine
            if !dataPoints.isEmpty, dataPoints.count >= 2 {
                let engine = Econometrics_Engine(data: dataPoints)
                let coefs = try engine.regression()
                regressionCoefs = coefs
                withAnimation { showChart = true }
            } else {
                withAnimation { showChart = false }
            }
            
            withAnimation { showResult = true }
        } catch let error as IPError {
            errorMessage = String(describing: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Royalty View
struct RoyaltyView: View {
    @State private var objectValueString = ""
    @State private var royaltyResult: Int?
    @State private var showResult = false
    @State private var hoverButton = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Royalty Calculator")
                .font(.largeTitle)
                .fontWeight(.light)
            
            VStack(alignment: .leading) {
                Text("Object Value (Int)")
                    .font(.headline)
                TextField("e.g. 10000", text: $objectValueString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Spacer()
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(hoverButton ? Color.purple.opacity(0.8) : Color.purple)
                    .frame(width: 180, height: 44)
                    .overlay(
                        Text("Compute Basic Royalty")
                            .foregroundColor(.white)
                            .font(.headline)
                    )
                    .scaleEffect(hoverButton ? 1.05 : 1.0)
                    .shadow(color: .purple.opacity(0.3), radius: hoverButton ? 8 : 4)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoverButton = hovering
                        }
                    }
                    .onTapGesture(perform: computeRoyalty)
                
                Spacer()
            }
            
            if showResult, let result = royaltyResult {
                HStack {
                    Spacer()
                    Text("Royalty (25%): \(result)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.purple)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                #if os(macOS)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                #else
                                    .fill(Color.gray)
                                #endif
                                .shadow(radius: 4)
                            
                        }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
        }
        .padding()
        .background{
            #if os(macOS)
                LinearGradient(
                    gradient: Gradient(colors: [Color(NSColor.windowBackgroundColor), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

            #else
                LinearGradient(
                    gradient: Gradient(
                        colors: [Color.purple, Color.purple.opacity(0.1)]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

            #endif
        }
    }
    
    private func computeRoyalty() {
        guard let value = Int(objectValueString) else { return }
        let royalties = IPBones_Royalties(objectValue: value)
        royaltyResult = royalties.method_Basic()
        withAnimation {
            showResult = true
        }
    }
}

// MARK: - Custom Disclosure Style for macOS
struct CustomDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            Button(action: { configuration.isExpanded.toggle() }) {
                HStack {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                    configuration.label
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 20)
                    .transition(.slide.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
