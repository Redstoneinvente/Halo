from pathlib import Path

path = Path('Halo/Views/WidgetSettingsView.swift')
text = path.read_text()
old = '''                let regionWidth = canvasSize.width * CGFloat(width)
                let regionHeight = canvasSize.height * CGFloat(height)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(regionTitle(region)).font(.system(size: 9, weight: .semibold))
                        Spacer()
                        Text("\\(Int((width * 100).rounded()))×\\(Int((height * 100).rounded()))%")
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(min(7, max(2, min(regionWidth, regionHeight) * 0.04)))
                .frame(width: max(1, regionWidth), height: max(1, regionHeight), alignment: .topLeading)
                .background((selectedRegion == region.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.045)), in: RoundedRectangle(cornerRadius: min(12, max(4, min(regionWidth, regionHeight) * 0.08))))
                .overlay(RoundedRectangle(cornerRadius: min(12, max(4, min(regionWidth, regionHeight) * 0.08))).stroke(selectedRegion == region.id ? Color.accentColor.opacity(0.75) : .white.opacity(0.08), lineWidth: selectedRegion == region.id ? 1.5 : 1))
'''
new = '''                let regionWidth = canvasSize.width * CGFloat(width)
                let regionHeight = canvasSize.height * CGFloat(height)
                let regionMinDimension = min(regionWidth, regionHeight)
                let previewPadding: CGFloat = min(7, max(2, regionMinDimension * 0.04))
                let previewCornerRadius: CGFloat = min(12, max(4, regionMinDimension * 0.08))
                let previewWidth: CGFloat = max(1, regionWidth)
                let previewHeight: CGFloat = max(1, regionHeight)
                let isSelected = selectedRegion == region.id
                let previewBackground: Color = isSelected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.045)
                let previewBorder: Color = isSelected ? Color.accentColor.opacity(0.75) : Color.white.opacity(0.08)
                let previewBorderWidth: CGFloat = isSelected ? 1.5 : 1
                let widthPercent = Int((width * 100).rounded())
                let heightPercent = Int((height * 100).rounded())
                let sizeLabel = "\\(widthPercent)×\\(heightPercent)%"
                let previewShape = RoundedRectangle(cornerRadius: previewCornerRadius)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(regionTitle(region)).font(.system(size: 9, weight: .semibold))
                        Spacer()
                        Text(sizeLabel)
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(previewPadding)
                .frame(width: previewWidth, height: previewHeight, alignment: .topLeading)
                .background(previewBackground, in: previewShape)
                .overlay(previewShape.stroke(previewBorder, lineWidth: previewBorderWidth))
'''
if text.count(old) != 1:
    raise SystemExit(f'Expected preview expression once, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
print('Simplified Visual Workspace preview expression.')
