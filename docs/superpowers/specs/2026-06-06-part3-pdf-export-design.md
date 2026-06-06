# Part 3 Design: Finalization, Review Loop & PDF Export

**Date:** 2026-06-06
**Branch:** export
**Scope:** What can be built now independently of Parts 1 & 2

---

## Context

Parts 1, 2, and 3 are being developed in parallel. Only Firebase authentication is currently implemented. Part 3 owns the Admin review loop, PDF generation, logo upload, and exception handling. Since Parts 1 and 2 are not yet done, we start with the two fully independent pieces: the PDF Cloud Function and logo upload. The Firestore schema defined here serves as a proposal for Part 1 to adopt.

---

## 1. Firestore Schema

### `exams/{examId}`
| Field | Type | Notes |
|---|---|---|
| `title` | string | Exam title |
| `courseName` | string | Name of the course |
| `semester` | string | Set by Admin on approval (e.g. "S1") |
| `year` | number | Set by Admin on approval (e.g. 2026) |
| `status` | string | `pending_admin_review` \| `approved` \| `rejected` \| `locked` |
| `adminId` | string | UID of the Admin who owns this exam |
| `revisionNotes` | string | Populated when Admin rejects |
| `pdfUrls` | map | `{ setA: string, setB: string }` — populated after generation |
| `logoUrl` | string | Firebase Storage URL — populated after logo upload |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

### `exams/{examId}/questions/{questionId}` (subcollection)
| Field | Type | Notes |
|---|---|---|
| `text` | string | Question text |
| `options` | array | `[{ label: "A"\|"B"\|"C"\|"D", text: string, isCorrect: boolean }]` |
| `topicName` | string | Denormalized for PDF rendering |
| `difficulty` | string | `Easy` \| `Medium` \| `Hard` |
| `order` | number | Display order in Set A |

### `users/{userId}`
| Field | Type | Notes |
|---|---|---|
| `email` | string | |
| `displayName` | string | |
| `role` | string | `super_admin` \| `admin` \| `user` |

> **Note for Part 1:** Committee and Teacher roles are stored in `examAssignments/{assignmentId}` (not on the user document) to support overlapping roles across exams. Fields: `examId`, `userId`, `role` (`committee` \| `committee_lead` \| `teacher`), `courseId`.

---

## 2. Cloud Function: `generateExamPdf`

### Type
Firebase HTTPS Callable Function (Node.js)

### Library
PDFKit (`pdfkit` npm package)

### Input
```json
{
  "examId": "string",
  "sets": ["A"] | ["A", "B"]
}
```

### Output
```json
{
  "pdfUrls": {
    "setA": "https://storage.googleapis.com/...",
    "setB": "https://storage.googleapis.com/..."
  }
}
```

### Execution Steps
1. Verify caller is an Admin via `users/{uid}.role`
2. Fetch exam document from `exams/{examId}`
3. Fetch all questions from `exams/{examId}/questions`, ordered by `order`
4. Generate Set A PDF — original question order, original option order
5. If Set B requested — shuffle question order, shuffle options within each question (correct answer moves with its option)
6. Upload PDF(s) to Firebase Storage: `exams/{examId}/setA.pdf`, `exams/{examId}/setB.pdf`
7. Write download URLs to `exams/{examId}.pdfUrls`
8. Return URLs to Flutter caller

### PDF Layout
```
[ Logo ]                    Institution Name
─────────────────────────────────────────────
Course: <courseName>        Semester: <semester> <year>
Set: A

Name: ___________________  Student ID: ________  Date: ________

Instructions: Circle the letter of the correct answer.

1. <question text>
   A. <option>
   B. <option>
   C. <option>
   D. <option>

2. ...

                                              Page N of Total
```

### Randomization Rule (Set B)
- Question order: full Fisher-Yates shuffle of the questions array
- Option order per question: Fisher-Yates shuffle of the options array
- Correct answer integrity: the `isCorrect` flag travels with its option object through the shuffle — no answer key corruption

### Storage Paths
- PDFs: `exams/{examId}/setA.pdf`, `exams/{examId}/setB.pdf`
- Logos: `logos/{examId}/logo.png`

---

## 3. Logo Upload Flow

### First-time print
1. Admin clicks "Print" on the exam screen
2. Dialog appears — file picker (PNG/JPG, max 2MB)
3. Flutter uploads to Firebase Storage: `logos/{examId}/logo.png`
4. On success: URL saved to `exams/{examId}.logoUrl`
5. Dialog closes — PDF generation triggered

### Repeat print (logo already exists)
1. Admin clicks "Print"
2. Dialog shows existing logo thumbnail with "Use this" / "Replace" options
3. If "Use this" — proceed directly to PDF generation
4. If "Replace" — show file picker, upload new logo, then generate

### Flutter Packages
- `file_picker` — image selection
- `firebase_storage` — upload with progress indicator

---

## 4. What We Are NOT Building Yet
These depend on Parts 1 & 2 being done first:
- Admin approve/reject UI (needs real exam documents in Firestore from Part 2)
- Revision notes loop (needs exam status written by Part 2)
- Teacher non-compliance alerts (needs assignment data from Parts 1 & 2)
- Quota reassignment / extension requests (same dependency)

---

## 5. Implementation Order
1. Set up Firebase Cloud Functions in the repo (`functions/` directory, Node.js)
2. Seed Firestore with a test exam + questions document
3. Build `generateExamPdf` Cloud Function with PDFKit
4. Build logo upload Flutter UI
5. Wire logo upload → Cloud Function call → display download links
