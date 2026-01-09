# EventBridge: BAUST Event Management System
## Project Launch Proposal & Approval Request

**Date:** January 9, 2026
**Project Name:** EventBridge (BAUST Event Management System)
**Platform:** Cross-Platform PWA (Android, iOS, Web)

---

## 1. Executive Summary

**EventBridge** is a comprehensive, digital solution designed specifically for Bangladesh Army University of Science and Technology (BAUST) to modernize and streamline the management of campus events. This application replaces fragmented, manual coordination methods with a centralized, data-driven platform that handles everything from participant registration to financial tracking and item distribution. This proposal outlines the critical operational challenges currently faced by BAUST and how EventBridge addresses them to improve transparency, efficiency, and student engagement.

---

## 2. Problem Statement: Current Challenges at BAUST

Currently, event management at BAUST relies heavily on manual processes and disjointed communication channels, leading to several operational inefficiencies:

### 2.1. Inefficient Registration Process
- **Current State:** Usage of paper lists or disjointed Google Forms that require manual data entry and consolidation.
- **Problem:** Prone to data entry errors, difficult to track real-time numbers, and laborious to verify payment status (Cash/bKash).
- **Result:** Long queues for confirmation, lost registration details, and administrative "heavy lifting."

### 2.2. Lack of Financial Transparency
- **Current State:** Expenses are tracked in loose spreadsheets or notebooks. Receipts are often physical and disconnected from the budget.
- **Problem:** Difficult to monitor budget burn-rate in real-time. "Mystery expenses" often appear at the end of an event.
- **Result:** Budget overruns and a lack of accountability for funds collected from students.

### 2.3. Operational Chaos (Item Distribution)
- **Current State:** Manual checklists for distributing t-shirts, food coupons, and kits.
- **Problem:** Slow distribution lines. Risk of double-claiming (one student taking two meals). Difficulty filtering needs by T-shirt size or food preference on the fly.
- **Result:** Inventory shortages, waste, and frustrated participants.

### 2.4. Fragmented Communication
- **Current State:** Notices spread via Facebook, WhatsApp groups, and notice boards.
- **Problem:** Students miss critical updates (schedule changes, room allocations). No centralized place for feedback or voting on event decisions.
- **Result:** Low engagement and misinformed participants.

---

## 3. The Solution: EventBridge Architecture

EventBridge solves these specific problems through a unified, role-based architecture:

### 3.1. Centralized Registration & Verification
- **Solution:** Digital registration flow with support for **bKash and Hand Cash**.
- **Access:** **Dedicated Google Sign-In** integration ensures secure, frictionless, one-tap login for students using their university or personal accounts.
- **Impact:** Real-time participant tracking. Organizers can approve pending payments instantly.
- **Feature:** **QR Code Integration** allows for instant, touchless check-in and identity verification, eliminating proxy attendance.

### 3.2. Real-Time Financial Tracking
- **Solution:** Dedicated **Expense Tracker** module with graphical analytics.
- **Impact:** Every expense is logged with categories and receipts. Organizers see a live "Available Balance" vs. "Spend" graph.
- **Feature:** Exportable financial reports for administrative audit (Excel format).

### 3.3. Smart Operations Management
- **Solution:** **Item Distribution Module** with digital checklists.
- **Impact:** Organizers scan a student's QR code or search by ID to mark items (Food, T-Shirt) as "Received".
- **Feature:** Prevents double-dipping and provides instant stats (e.g., "150/200 T-Shirts distributed").

### 3.4. Enhanced Engagement & Communication
- **Solution:** Built-in **Notifications** and **Polls**.
- **Impact:** Admins can push instant updates to all users. Organizers can run polls to decide menu items or event themes.
- **Technical Edge:** As a PWA (Progressive Web App), it works offline in low-connectivity areas common on campus.

---

## 4. Key Features Summary

| Feature Category | Capabilities |
|-----------------|--------------|
| **For Administration** | • Dashboard overview of all campus events<br>• User role management (promote organizers)<br>• Global analytics and exportable reports |
| **For Organizers** | • Create/Edit events with rich details<br>• Manage budget & expenses (Graphs)<br>• QR Scanner for check-ins/distribution<br>• Real-time participant filtering (Batch, Gender, Hall) |
| **For Students** | • One-tap registration<br>• Personal QR Profile<br>• Real-time notifications<br>• Event history & resource access |

---

## 5. Technical Advantages & Strategic Cost Savings

- **smart iOS Strategy (Zero Cost):**
  - **Native App Cost:** Publishing a dedicated iOS app requires an annual Apple Developer fee of **$99 USD/year**.
  - **PWA Solution:** By deploying as a **Progressive Web App (PWA)**, we provide iPhone users with an "app-like" experience (Home Screen icon, offline support) **completely free of charge**.
  - **Free Hosting:** The platform is hosted via **GitHub Services**, ensuring **zero server costs** for the university while maintaining high uptime and security.

- **Cross-Platform Accessibility:** Works seamlessly on Android, iOS, and Desktop browsers without requiring app store downloads.
- **Security:** Built on Google Firebase with secure authentication (Email/Google Sign-In) and robust database rules to protect student data.
- **Scalability:** Capable of handling large university fests with thousands of concurrent users.
- **Offline Capable:** Critical features work even when internet connectivity is spotty.

---

## 6. Conclusion & Request for Approval

EventBridge represents a significant leap forward in how BAUST manages its extracurricular landscape. By digitizing manual workflows, we ensure that **funds are transparent, queues are shorter, and students are better connected.**

We request approval to launch EventBridge as the official event management platform for the upcoming semester, allowing us to pilot the system with a live event to demonstrate its efficacy.

**Prepared By:**
[Your Name/Team Name]
[Department/Batch]
BAUST
