# Backend Specification (BACKEND_SPEC.md)

This document outlines the database schemas, access control rules, API specifications, and cloud function structures for the **Exam Drafter** backend. It will be updated continuously throughout the development lifecycle.

---

## 1. Authentication

Exam Drafter uses **Firebase Authentication** for user authentication (Email and Password).
- **Self-registration**: Users can register an account.
- **Default Role**: Newly registered users are assigned a status of `unassigned` (or default roles) until an Admin/Super Admin grants them specific roles.

---

## 2. Database Schema (Firestore)

### Collection: `users`
Tracks user information and role mappings.
```typescript
interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  createdAt: Timestamp;
  // Overlapping roles mapping: key can be a department ID, course ID, or "global"
  roles: {
    global?: 'super_admin' | 'admin' | 'user';
    [contextId: string]: 'committee_lead' | 'committee_member' | 'teacher';
  };
}
```

### Collection: `departments`
```typescript
interface Department {
  id: string;
  name: string;      // e.g., "Computer Science"
  code: string;      // e.g., "CS"
  createdAt: Timestamp;
}
```

### Collection: `courses`
```typescript
interface Course {
  id: string;
  departmentId: string; // Ref to department
  name: string;         // e.g., "Introduction to Programming"
  code: string;         // e.g., "CS101"
  createdAt: Timestamp;
}
```

### Collection: `topics`
Topics can span multiple courses.
```typescript
interface Topic {
  id: string;
  name: string;         // e.g., "Recursion"
  courseIds: string[];  // List of course IDs associated with this topic
  createdAt: Timestamp;
}
```

### Collection: `questions`
Contains individual multiple choice questions. Once approved, documents are **immutable**. Edits must create new document instances.
```typescript
interface Question {
  id: string;
  text: string;
  options: string[];          // List of 4-5 options
  correctOptionIndex: number; // Index of the correct answer in options
  difficulty: 'easy' | 'medium' | 'hard';
  topicIds: string[];         // Topics associated with this question
  courseId: string;           // Course associated with this question
  authorUid: string;          // Teacher who drafted it
  version: number;            // Starts at 1
  status: 'draft' | 'submitted' | 'approved' | 'deprecated'; // 'deprecated' replaces "Error - Do Not Use"
  replacedById?: string;      // Pointer to the newer version if this is deprecated
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### Collection: `exam_requests`
Represents the commissioning of an exam by an Admin.
```typescript
interface ExamRequest {
  id: string;
  section: string;            // e.g., "Section A"
  departmentId: string;
  courseId: string;
  questionCount: number;      // Quota of questions needed
  difficultyDistribution: {   // e.g., { easy: 5, medium: 3, hard: 2 }
    easy: number;
    medium: number;
    hard: number;
  };
  adminDeadline: Timestamp;   // Final approval deadline
  internalDeadline?: Timestamp; // Deadline for Teachers set by Committee (at least 24h prior)
  status: 'commissioned' | 'delegated' | 'curating' | 'submitted_to_admin' | 'approved' | 'returned_for_revision';
  revisionNotes?: string;     // Notes left by Admin on rejection
  createdByUid: string;       // Admin UID
  createdAt: Timestamp;
}
```

### Collection: `exam_curations`
Holds progress, allocations, votes, and final selected questions for an active `ExamRequest`.
```typescript
interface ExamCuration {
  examRequestId: string;
  // Quota split among teachers
  teacherDelegations: {
    teacherUid: string;
    courseId: string;
    questionCount: number;
  }[];
  // Submissions pool votes: questionId -> list of voter UIDs
  votes: {
    [questionId: string]: string[];
  };
  // Selection markers
  selectedQuestionIds: string[];
  finalizedByUid?: string;    // Committee Lead UID
  finalizedAt?: Timestamp;
}
```

---

## 3. Firebase Cloud Functions

### Function: `generateExamPdf`
- **Trigger**: Callable HTTPS Request (`onCall`)
- **Inputs**:
  ```typescript
  {
    examRequestId: string;
    generateTwoSets: boolean; // True to generate Set A and Set B
    logoUrl?: string;         // Custom institution logo stored in Firebase Storage
  }
  ```
- **Behavior**:
  1. Fetches the curated questions for the specified `examRequestId`.
  2. Generates **Set A**: Formats metadata, logo, and question list.
  3. Generates **Set B** (if requested): Shuffles the question list and the order of choice choices within each question. The correct answer index mapping must be resolved correctly during shuffle.
  4. Renders PDFs server-side using `pdf-lib` or `pdfkit`.
  5. Saves the files to Firebase Storage (`exams/{examRequestId}/set_a.pdf` and `set_b.pdf`).
- **Output**:
  ```typescript
  {
    success: boolean;
    setAPdfUrl: string;
    setBPdfUrl?: string;
  }
  ```

---

## 4. Firestore Security Rules (Summary Plan)
- **Super Admin**: Read/Write access to `departments`, `courses`, `topics`, and user roles.
- **Admin**: Create `exam_requests`, view all data, and update exam status (Approve/Reject).
- **Committee**: Read all taxonomy and exam requests. Write access to `exam_curations` and voting records.
- **Teacher**: Read assigned quotas. Write access to create/update their own `questions` in `draft` or `submitted` status.
