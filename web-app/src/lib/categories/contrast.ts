function linearChannel(value: number): number {
  const channel = value / 255;
  return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
}

export function contrastRatio(hex: string, foreground: "#000000" | "#FFFFFF"): number {
  const normalized = hex.replace(/^#/, "");
  if (!/^[\da-fA-F]{6}$/.test(normalized)) throw new Error("Expected a six-digit hex color.");
  const channels = [0, 2, 4].map((index) => Number.parseInt(normalized.slice(index, index + 2), 16));
  const luminance = channels.reduce((sum, channel, index) => sum + linearChannel(channel) * [0.2126, 0.7152, 0.0722][index], 0);
  const foregroundLuminance = foreground === "#000000" ? 0 : 1;
  const lighter = Math.max(luminance, foregroundLuminance);
  const darker = Math.min(luminance, foregroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

export function cardForeground(background: string): "#000000" | "#FFFFFF" {
  return contrastRatio(background, "#000000") >= 4.5 ? "#000000" : "#FFFFFF";
}
