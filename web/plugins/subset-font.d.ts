declare module 'subset-font' {
  export default function subset(font: Buffer, text: string, options: { targetFormat: 'woff2' | 'woff' | 'truetype' }): Promise<Buffer>
}
