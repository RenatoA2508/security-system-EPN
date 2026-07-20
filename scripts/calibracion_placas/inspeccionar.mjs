import { readFile } from 'node:fs/promises'
import { PNG } from 'pngjs'
import { createWorker } from 'tesseract.js'
const w = await createWorker('eng')
await w.setParameters({ tessedit_char_whitelist:'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', tessedit_pageseg_mode:'7' })
const png = PNG.sync.read(await readFile(process.argv[2]))
const url = 'data:image/png;base64,'+PNG.sync.write(png).toString('base64')
const r = await w.recognize(url)
console.log('claves de data:', Object.keys(r.data))
console.log('confidence:', r.data.confidence)
console.log('texto:', JSON.stringify((r.data.text||'').trim()))
console.log('words?', Array.isArray(r.data.words), r.data.words?.length)
const r2 = await w.recognize(url, {}, { blocks: true, text: true })
console.log('--- con blocks:true ---')
console.log('confidence:', r2.data.confidence, '| blocks:', r2.data.blocks?.length)
if (r2.data.blocks?.[0]) {
  const b = r2.data.blocks[0]
  console.log('block conf:', b.confidence, '| paragraphs:', b.paragraphs?.length)
  const words = b.paragraphs?.[0]?.lines?.[0]?.words
  console.log('words:', words?.map(x=>`${x.text}:${x.confidence?.toFixed(1)}`).join(' '))
}
await w.terminate()
