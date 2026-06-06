const { initializeApp } = require('firebase-admin/app');
initializeApp();

const { generateExamPdf } = require('./src/generateExamPdf');
exports.generateExamPdf = generateExamPdf;
