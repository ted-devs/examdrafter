const PDFDocument = require('pdfkit');
const https = require('https');
const http = require('http');

const LAYOUT = {
  margin: 50,
  questionNumberWidth: 20,
  questionTextOffset: 120,
  pageBreakThreshold: 120,
};

function fetchImageBuffer(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function buildExamPdf(exam, questions, set, logoUrl) {
  let logoBuffer = null;
  if (logoUrl) {
    try {
      logoBuffer = await fetchImageBuffer(logoUrl);
    } catch (_) {
      // logo fetch failed — continue without it
    }
  }

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: LAYOUT.margin, bufferPages: true });
    const buffers = [];
    doc.on('data', (chunk) => buffers.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);

    try {
      // --- Header ---
      const headerY = doc.y;
      if (logoBuffer) {
        doc.image(logoBuffer, LAYOUT.margin, headerY, { width: 60 });
      }
      doc.fontSize(16).font('Helvetica-Bold')
        .text('Exam Drafter Institution', LAYOUT.margin, headerY, { align: 'right' });

      doc.moveDown(0.5);
      doc.fontSize(11).font('Helvetica')
        .text(`Course: ${exam.courseName}`, { continued: true })
        .text(`Semester: ${exam.semester} ${exam.year}`, { align: 'right' });
      doc.text(`Set: ${set}`);

      doc.moveDown(0.8);
      doc.moveTo(LAYOUT.margin, doc.y).lineTo(doc.page.width - LAYOUT.margin, doc.y).stroke();
      doc.moveDown(0.8);

      // --- Student info ---
      doc.text('Name: _________________________    Student ID: ____________    Date: ____________');
      doc.moveDown(1);

      // --- Instructions ---
      doc.font('Helvetica-Bold').text('Instructions: ', { continued: true })
        .font('Helvetica').text('Circle the letter of the correct answer.');
      doc.moveDown(1);

      // --- Questions ---
      questions.forEach((q, index) => {
        const remainingSpace = doc.page.height - doc.page.margins.bottom - doc.y;
        if (remainingSpace < LAYOUT.pageBreakThreshold) {
          doc.addPage();
        }

        doc.font('Helvetica-Bold')
          .text(`${index + 1}.`, LAYOUT.margin, doc.y, { continued: true, width: LAYOUT.questionNumberWidth })
          .font('Helvetica')
          .text(` ${q.text}`, { width: doc.page.width - LAYOUT.questionTextOffset });
        doc.moveDown(0.3);

        q.options.forEach((opt) => {
          doc.text(`    ${opt.label}.  ${opt.text}`, { indent: 20 });
        });
        doc.moveDown(0.8);
      });

      // --- Page numbers ---
      const range = doc.bufferedPageRange();
      for (let i = range.start; i < range.start + range.count; i++) {
        doc.switchToPage(i);
        doc.fontSize(9).font('Helvetica')
          .text(
            `Page ${i + 1} of ${range.count}`,
            LAYOUT.margin,
            doc.page.height - doc.page.margins.bottom - 10,
            { align: 'right' },
          );
      }

      doc.flushPages();
      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

module.exports = { buildExamPdf };
