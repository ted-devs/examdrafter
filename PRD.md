# Product Requirements Document: Exam Drafter
## 1. System Overview
Exam Drafter is a Flutter-based desktop web application designed to streamline the collaborative creation, review, and management of institutional exam papers. It provides a structured workflow from exam commissioning to PDF generation, backed by Firebase for real-time notifications, data storage, and server-side document rendering.
## 2. User Roles & Access Control
The system supports overlapping roles, meaning a user can act as a Teacher for one course while serving on the Section Committee for another.
- Super Admin: Responsible for initial system setup and ongoing taxonomy management (Departments, Courses, Topics).
- Admin: Initiates exam requests, sets global deadlines, reviews finalized exams (approve/reject), and triggers the final PDF generation.
- Section Committee: A group of one or more users tasked with fulfilling the Admin's exam request.
  - Committee Lead: A designated member who holds the tie-breaking vote during the question selection process.
- Teacher: Assigned by the committee to draft Multiple Choice Questions (MCQs) for specific topics and courses.
## 3. Data Taxonomy & Question Schema
All data is structured relationally, managed by the Super Admin, and stored in Firebase Firestore.
- Taxonomy Hierarchy: Department → Courses → Topics. (Note: Topics can span multiple courses.)
- Question Schema: Every drafted question must contain:
  - Question Text
  - Related Topic(s)
  - 4-5 Multiple Choice Options (with the correct answer indicated)
  - Difficulty Metadata (e.g., Easy, Medium, Hard)
## 4. The Exam Generation Workflow
1. Exam Commissioning (Action by Admin): The Admin creates an exam request specifying the target section, involved courses, required question count per course, and the final approval deadline. This request is dispatched to the relevant Section Committee.
2. Delegation (Action by Section Committee): The Committee reviews the request and distributes quotas to course Teachers. Because a course may have multiple teachers, the Committee can split the quota. The internal deadline set for Teachers must be at least 24 hours prior to the Admin's final deadline.
3. Question Drafting (Action by Teachers): Teachers draft their allocated MCQs with text, topics, options, and difficulty metadata. Upon submission, the questions enter the Committee's review pool.
4. Collaborative Curation (Action by Section Committee): If Teachers submit more questions than required, the Committee votes on which to keep. The questions with the lowest votes are dropped. If a vote results in a tie, the Committee Lead's vote serves as the tie-breaker.
5. Admin Review / The Revision Loop (Action by Admin): The curated exam is sent to the Admin.
    - Approval: The Admin accepts the paper, tags it with the Semester and Year, and locks it.
    - Rejection: The Admin sends the paper back to the Section Committee with revision notes, restarting the curation phase.
## 5. Exception Handling & Edge Cases
- Teacher Non-Compliance: If a Teacher misses the deadline or fails to submit the requested quota, the system alerts the Section Committee. The Committee can either reassign the missing quota to another Teacher or submit a formal extension request to the Admin.
- Question Immutability: Once a question is approved and saved to the Question Bank, it cannot be overwritten. If an error (e.g., a typo or wrong answer key) is discovered later, editing the question generates a completely new version. The original question remains in historical exam records but is flagged as "Error - Do Not Use" in the active question bank.
## 6. Exam Bank & Reusability
All approved questions and finalized exams are archived in the database. The taxonomy and difficulty tags allow future Section Committees to query the bank and reuse historically proven questions for new exams, filtering by topic, difficulty, or course.
## 7. Export & PDF Generation
To ensure high-quality formatting and reduce client-side performance issues, document rendering is handled server-side via Firebase Cloud Functions.
- Print Setup: When the Admin clicks "Print," they are prompted to upload/select the institution's logo.
- Randomization: The Admin can choose to generate up to 2 different sets (Set A and Set B) of the same exam. The Cloud Function will shuffle both the question order and the MCQ choices for the second set.
- Output: The Cloud Function formats the exam into a traditional academic paper layout and returns direct download links for the PDFs to the Admin's dashboard.
## 8. Technical & Development Guidelines
- Frontend: Flutter (compiled for Desktop Web).
- Backend: Firebase (Firestore for database, Firebase Cloud Messaging for notifications, Cloud Functions for PDF generation).
- Development Standards: Developers may use their preferred IDE and AI tools, but all code must conform to a standardized set of rules documented in the repository's .md guidelines file to ensure consistency across the codebase.
