Based on the `Product Requirements Document: Exam Drafter`, the development work can be divided into three simultaneous parts. This separation minimizes merge conflicts by isolating the core backend setup, the primary user workflow, and the specialized server-side export function.

### **Development Work Division (3 Parts)**

#### **Part 1: Core Backend Infrastructure and Super Admin/Admin Setup**

**Focus:** Establishing the foundational data structures and core system configuration using Firebase (Firestore) and the initial administrative user interfaces (Flutter).

  * **System Setup & Taxonomy Management:** Implement the Super Admin role and the UI for managing the `Department → Courses → Topics` taxonomy hierarchy.
  * **Data Models & Access Control:** Define the Firestore data models for the **Question Schema** (text, topic(s), options, difficulty) and the relational database structure. Implement Firebase security rules for all user roles (Super Admin, Admin, Committee, Teacher).
  * **Exam Commissioning:** Implement the Admin's feature for initiating an exam request, specifying sections, courses, question counts, and deadlines.
  * **Exam Bank Foundation:** Set up the database structure for archiving approved questions and finalized exams for reusability.

#### **Part 2: Teacher Drafting and Collaborative Curation Workflow**

**Focus:** Building the main user-facing workflow where content is generated, reviewed, and selected (Flutter Frontend heavy).

  * **Question Drafting UI:** Implement the Teacher role UI, allowing them to draft MCQs based on their delegated quota, including all required Question Schema fields.
  * **Delegation & Review Pool:** Implement the Section Committee's action to review the Admin's request and distribute quotas to Teachers. Manage the submission process where drafted questions enter the Committee's review pool.
  * **Collaborative Curation Logic:** Implement the Committee's voting system for selecting which questions to keep, including the Committee Lead's tie-breaking vote.
  * **Question Immutability:** Enforce the rule that editing an approved question creates a completely new version, while the original is flagged as "Error - Do Not Use".

#### **Part 3: Finalization, Review Loop, and PDF Export Service**

**Focus:** Implementing the final stage of the workflow and the specialized server-side rendering logic (Firebase Cloud Functions).

  * **Admin Review and Revision Loop:** Implement the Admin's final review UI, allowing them to **Approve** (tagging with Semester/Year and locking) or **Reject** the paper (sending it back with revision notes to the Section Committee).
  * **PDF Generation Cloud Function:** Develop the Firebase Cloud Function responsible for server-side document rendering. This function must format the exam into an academic paper layout.
  * **Export Randomization:** Integrate the logic within the Cloud Function to generate up to two different sets (Set A and Set B) by shuffling question order and MCQ choices.
  * **Print Setup:** Implement the prompt for the Admin to upload/select the institution's logo prior to printing.
  * **Exception Handling:** Implement the logic and notifications for **Teacher Non-Compliance** (deadlines/quotas) and the Committee's ability to reassign quotas or request extensions.
