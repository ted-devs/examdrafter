const PDFDocument = require('pdfkit');
const https = require('https');
const http = require('http');

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

function buildExamPdf(exam, questions, set, logoUrl) {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 50, bufferPages: true });
      const buffers = [];
      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', reject);

      // --- Header ---
      const headerY = doc.y;
      if (logoUrl) {
        try {
          const logoBuffer = await fetchImageBuffer(logoUrl);
          doc.image(logoBuffer, 50, headerY, { width: 60 });
        } catch (_) {
          // logo fetch failed — continue without it
        }
      }
      doc.fontSize(16).font('Helvetica-Bold')
        .text('Exam Drafter Institution', 50, headerY, { align: 'right' });

      doc.moveDown(0.5);
      doc.fontSize(11).font('Helvetica')
        .text(`Course: ${exam.courseName}`, { continued: true })
        .text(`Semester: ${exam.semester} ${exam.year}`, { align: 'right' });
      doc.text(`Set: ${set}`);

      doc.moveDown(0.8);
      doc.moveTo(50, doc.y).lineTo(doc.page.width - 50, doc.y).stroke();
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
        const questionY = doc.y;
        const remainingSpace = doc.page.height - doc.page.margins.bottom - questionY;
        if (remainingSpace < 120) {
          doc.addPage();
        }

        doc.font('Helvetica-Bold').text(`${index + 1}.`, 50, doc.y, { continued: true, width: 20 })
          .font('Helvetica').text(` ${q.text}`, { width: doc.page.width - 120 });
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
            50,
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
