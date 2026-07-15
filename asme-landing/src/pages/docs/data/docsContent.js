// Documentation Content in English, Hindi, and Bengali

export const languages = [
  { code: "en", name: "English", nativeName: "English" },
  { code: "hi", name: "Hindi", nativeName: "हिंदी" },
  { code: "bn", name: "Bengali", nativeName: "বাংলা" },
  { code: "ta", name: "Tamil", nativeName: "தமிழ்" },
  { code: "te", name: "Telugu", nativeName: "తెలుగు" },
  { code: "kn", name: "Kannada", nativeName: "ಕನ್ನಡ" },
  { code: "ml", name: "Malayalam", nativeName: "മലയാളം" },
  { code: "mr", name: "Marathi", nativeName: "मराठी" },
  { code: "gu", name: "Gujarati", nativeName: "ગુજરાતી" },
  { code: "or", name: "Odia", nativeName: "ଓଡ଼ିଆ" },
  { code: "pa", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ" },
];

export const docsContent = {
  // ──────────────────────────────────────────────────────────────────────────
  // ENGLISH
  // ──────────────────────────────────────────────────────────────────────────
  en: {
    common: {
      allGuides: "All Guides",
      backToHome: "Home",
      documentation: "Documentation",
      quickLinks: "Quick Links",
      portalGuides: "Portal Guides",
      watchVideo: "Watch Video",
      openGuide: "Open Guide",
      stepsTitle: "Step-by-Step Guide",
      lessons: "lessons",
      portals: "portals",
      youtube: "YouTube",
      selectPortal: "Select Your Portal",
      openGuideAction: "Open guide",
      subscribe: "Subscribe",
      popularGuides: "Popular Guides",
      youtubeCtaTitle: "Video Tutorials Available",
      youtubeCtaDesc: "Detailed video tutorials for every topic. Explained in simple, easy-to-follow steps. Subscribe to our YouTube channel to get updates on new videos.",
    },
    home: {
      title: "Documentation",
      subtitle: "Portal-wise guides with video tutorials",
      desc: "MicroFlow Pro — Complete guide for every portal. Watch video walkthroughs and follow simple instructions to manage your microfinance operations.",
      portals: {
        admin: {
          title: "Executive Admin",
          desc: "Full organization setup, branch management, staff oversight, and deep reports/analytics."
        },
        manager: {
          title: "Branch Manager",
          desc: "Manage your specific branch collections, loan approvals, savings deposits, and monitor branch staff."
        },
        agent: {
          title: "Collection Agent",
          desc: "Field operations guide including daily collection tracking, duty toggle, live location, and SMS alerts."
        },
        customer: {
          title: "Customer App",
          desc: "A guide for customers to check outstanding loans, savings balance, recent payment history, and download statements."
        }
      },
      topics: [
        { label: "📱 App Download & Login", path: "/docs/customer" },
        { label: "👤 Add A Member", path: "/docs/collection-agent" },
        { label: "💰 Daily Collection Process", path: "/docs/collection-agent" },
        { label: "📊 Loan Statement PDF", path: "/docs/customer" },
        { label: "🛡️ Team, Activity & Audit Log", path: "/docs/executive-admin" },
        { label: "📨 Configure SMS Alerts", path: "/docs/executive-admin" },
        { label: "📍 Agent Live Tracking", path: "/docs/branch-manager" },
        { label: "🔐 Force Password Reset", path: "/docs/executive-admin" }
      ]
    },
    executiveAdmin: {
      title: "Executive Admin Guide",
      desc: "As an Executive Admin you own your organization end-to-end — register it, brand it, set plans and limits, add staff and members, run loans and savings, and configure SMS. This guide walks through every feature.",
      lessons: [
        {
          icon: "🚀",
          title: "Organization Registration",
          steps: [
            { label: "On the Sign In screen, tap 'Create Organization'.", desc: "The Create Account form opens — 'Set up your organization in minutes'." },
            { label: "Fill the 6 required fields.", desc: "Organization Name, your Full Name, Email, 10-digit Phone, Password (min 8 chars) and Confirm Password." },
            { label: "Accept the Terms and tap 'Create Organization'.", desc: "A checkbox confirms you agree to the Terms of Service and Privacy Policy." },
            { label: "Verify your email, then sign in.", desc: "We send a verification link to your email. Click it, then sign in — your organization is created automatically with a 14-day free trial." }
          ],
          note: "Your account is created as the Executive Admin. No plan is chosen at signup — you start on a 14-day trial (up to 10 branches, 5 staff, 100 members)."
        },
        {
          icon: "🏠",
          title: "First Login & My Org Dashboard",
          steps: [
            { label: "Sign in to land on your My Org dashboard.", desc: "This is your organization's home — a snapshot of everything happening." },
            { label: "Review the Overview stats.", desc: "Members, Staff, Active Loans, Total Disbursed, Outstanding, and Total Loans at a glance." },
            { label: "Use Quick Actions to jump in.", desc: "Collect Payment, UPI Verify, Add Staff, New Member, New Loan, New Savings, and Branches." }
          ],
          note: "Tap 'My Org' (top-right) any time to return here. Pull down to refresh the latest numbers."
        },
        {
          icon: "🎨",
          title: "Organization Profile & Branding",
          steps: [
            { label: "Open Organization Settings.", desc: "From the dashboard tap 'Edit Organization Settings', or go to Settings → Organization Settings." },
            { label: "Update your profile.", desc: "Change the Organization Name and Slug (used in URLs, e.g. my-mfi). Only the slug must be unique." },
            { label: "Upload your logo.", desc: "Tap the logo box and pick a 512×512 image. It uploads to your org assets and shows across all staff portals." },
            { label: "Set your brand colors.", desc: "Enter a Primary and Accent color (hex, e.g. #6366F1). The theme syncs across every portal for your org." }
          ],
          note: "Logo and brand colors can take a couple of minutes to sync across all portals."
        },
        {
          icon: "💳",
          title: "Plan, Status & Limits",
          steps: [
            { label: "Open your org's detail or settings page.", desc: "From the dashboard tap the org card, or 'Edit Organization Settings'." },
            { label: "Switch the plan.", desc: "Tap the plan badge (Free / Basic / Pro / Enterprise) and pick a plan from the sheet." },
            { label: "Change the status.", desc: "Tap the status chip to Activate, Suspend, or set to Trial. A suspended org is hidden from active use." },
            { label: "Set your plan limits.", desc: "Under Plan Limits, set Max Branches, Max Staff, and Max Members. Usage bars show how close you are to each limit." }
          ],
          note: "During your 14-day trial you get 10 branches / 5 staff / 100 members. Upgrading raises these caps."
        },
        {
          icon: "⚙️",
          title: "Settings Overview",
          steps: [
            { label: "Open Settings from the menu.", desc: "Five sections appear: Account & Preferences, Organization Controls, System Connectivity, Security & Compliance, Utilities & Support." },
            { label: "Account & Preferences.", desc: "Profile (name, phone, email, password), Dark Mode, Biometric login, Push Alerts, and the AI Assistant toggle." },
            { label: "Organization Controls (admin only).", desc: "Organization Settings (branding, legal, address) and Loan & Savings Products (schemes, rates, limits)." },
            { label: "System Connectivity (admin only).", desc: "Integrations — connect SMS, UPI, WhatsApp, SMTP, Razorpay, and PhonePe." },
            { label: "Security & Compliance.", desc: "Security Shield & Activity Logs, 2FA, password policy, auto-logout, and Google Drive backup." }
          ],
          note: "Branding and plan limits also live under Organization Settings reached from the dashboard."
        },
        {
          icon: "👥",
          title: "Add Staff & Manage Users",
          steps: [
            { label: "Open Users.", desc: "From Quick Actions tap 'Add Staff', or go to the Users page." },
            { label: "Create a new user.", desc: "Go to /users/new and enter their name, email, phone, and role (Manager or Collection Agent)." },
            { label: "Review the user list.", desc: "The Users page lists everyone with role filters (Admin, Manager, Agent) and search by name or email." },
            { label: "Enforce two-factor auth.", desc: "In Security & Compliance → Two-Factor Authentication, enforce 2FA and choose the method (Authenticator app or SMS) per role." }
          ],
          note: "Staff sign in with the email you register — they set their own password on first login."
        },
        {
          icon: "🧑‍🤝‍🧑",
          title: "Onboard Members (Customers)",
          steps: [
            { label: "Start member onboarding.", desc: "From Quick Actions tap 'New Member', or go to the Members page → Onboard Member." },
            { label: "Enter member details.", desc: "Full name, verified mobile, address, and a primary document ID (Aadhaar / Voter)." },
            { label: "Collect KYC documents.", desc: "Upload the KYC document photos. KYC should be verified before any loan is disbursed." },
            { label: "Submit the profile.", desc: "The system creates the member with a unique Member ID linked to your org." }
          ],
          note: "Each member has an SMS Notifications toggle on their loan and savings pages — this is their only SMS opt-out."
        },
        {
          icon: "🏢",
          title: "Manage Branches",
          steps: [
            { label: "Open Branches.", desc: "From Quick Actions tap 'Branches', or open it from Organization Settings." },
            { label: "Add a branch.", desc: "Tap to create a branch and enter its Name, Code, and location (zone / district)." },
            { label: "Review the branch list.", desc: "Your org detail page lists all branches with their code and active/suspended status." },
            { label: "Assign a manager.", desc: "Each branch is tied to a Branch Manager you invited under Users." }
          ],
          note: "Branch codes are unique within your org and are used to filter reports and collections."
        },
        {
          icon: "💰",
          title: "Loans — Create & Track",
          steps: [
            { label: "Open New Loan.", desc: "From Quick Actions tap 'New Loan' (the 'Deploy Capital' page)." },
            { label: "Enter loan details.", desc: "Pick the Borrower (member), Principal (₹1K–₹10L), Interest (APR % or fixed amount, per day/week/month/year), Interest Logic (flat or reducing), First Installment Date, Tenure, and Collection Type (Daily/Weekly/Monthly/Yearly)." },
            { label: "Review the live summary.", desc: "The Financial Summary shows estimated installment, total interest, and a full amortization (EMI) preview before you save." },
            { label: "Track the active loan.", desc: "Loans are created live (active) — no approval gate. The loan detail shows outstanding balance, due alerts (OVERDUE / DUE TODAY), EMI timeline, and Loan Intelligence." },
            { label: "Manage the loan.", desc: "From the '…' menu: Edit, Mark Defaulted, Reactivate, Restructure, Freeze Skipped EMIs, or Delete." }
          ],
          note: "EMI statuses include PAID, DUE, OVERDUE, WAIVED, PENDING, and FROZEN. Collect / Settle / Reminder actions appear for open loans."
        },
        {
          icon: "🏦",
          title: "Savings — Manage Plans",
          steps: [
            { label: "Open New Savings Plan.", desc: "From Quick Actions tap 'New Savings'." },
            { label: "Enter plan details.", desc: "Pick the Member, Collection Cycle (Daily/Weekly/Monthly/Yearly), Installment Amount (₹10–₹50K), Start Date, Tenure, Maturity Amount, and Premature Penalty %." },
            { label: "Review the Wealth Forecast.", desc: "Live preview shows guaranteed maturity, total installments, total capital, and estimated yield." },
            { label: "Deposit & withdraw.", desc: "Deposit any time from the collection sheet. Withdrawals go to a Withdrawal Requests queue (Pending/Approved/Rejected) where a manager approves or rejects with a reason." },
            { label: "Manage the vault.", desc: "Pause/Resume the vault, Close the account, or (admin only) Delete permanently. Balances and a yield-projection chart are shown." }
          ],
          note: "Savings are Principal Protected. Premature withdrawal applies the penalty % you set at creation."
        },
        {
          icon: "📨",
          title: "SMS & Notifications",
          steps: [
            { label: "Open SMS Settings.", desc: "Settings → Integrations → Communications tab → Local SMS. This opens the SMS Settings page (admin only)." },
            { label: "Turn on auto-receipts.", desc: "'SMS on Collection' and 'SMS on Savings Deposit' are ON by default — customers get a receipt after every transaction." },
            { label: "Enable EMI reminders.", desc: "Toggle 'Due EMI Reminders' (OFF by default) and set a daily Reminder Time. Templates use {name}, {amount}, {loan_id}, {balance}." },
            { label: "Pick the SIM slot.", desc: "Under SIM & Outbox, choose which device SIM sends SMS, send a test SMS, and view Sent SMS history (last 200)." },
            { label: "Per-member opt-out.", desc: "On any loan or savings detail page, toggle 'SMS Notifications' to enable/disable reminders for that member." }
          ],
          note: "SMS is sent from the device's SIM (native Android plugin) — there is no external SMS gateway. WhatsApp and Email are configured separately under Integrations."
        },
        {
          icon: "💸",
          title: "Collect Payments & UPI Verify",
          steps: [
            { label: "Open Collect Payment.", desc: "From Quick Actions tap 'Collect Payment' to start a collection." },
            { label: "Log the collection.", desc: "Pick the member/loan, enter the amount, choose the mode (Cash, UPI, or Bank), and submit. A receipt SMS is sent automatically if enabled." },
            { label: "Verify UPI payments.", desc: "From Quick Actions tap 'UPI Verify' to confirm a customer's UPI reference against the expected payment." }
          ],
          note: "Collections appear instantly on the dashboard's Recent Collections and sync to the cloud."
        },
        {
          icon: "🛡️",
          title: "Team, Activity & Audit Log",
          steps: [
            { label: "Open your org detail page.", desc: "Tap any org card on the dashboard to see the full summary." },
            { label: "View Team Members.", desc: "The Team tile lists all staff with role-coloured avatars and a name/email search and role filter." },
            { label: "Check Recent Activity.", desc: "The Activity tile shows a log of actions (auth, loan, payment, savings, member) with who did what and when." },
            { label: "Open Security & Activity Logs.", desc: "In Settings → Security & Compliance, open System Activity Logs and configure audit retention, password policy, and Google Drive backup." }
          ],
          note: "Audit logs help you trace every change — useful during reviews or disputes."
        }
      ]
    },
    branchManager: {
      title: "Branch Manager Guide",
      desc: "As a Branch Manager, you control branch operations. Onboard new members (customers), monitor agent locations, manage daily cash inflows, and audit local registries.",
      lessons: [
        {
          icon: "🚀",
          title: "Getting Started — Manager Dashboard",
          steps: [
            { label: "Open email invite from Executive Admin.", desc: "Access default registry setup link." },
            { label: "Set up login password and authenticate your account.", desc: "Save profile with correct phone credentials." },
            { label: "Inspect the Branch Dashboard to view daily targets and collections." }
          ]
        },
        {
          icon: "👥",
          title: "Customer Onboarding (Members)",
          steps: [
            { label: "Go to Members > Onboard Member.", desc: "Ensure you have physical KYC sheets ready." },
            { label: "Enter full name, verified mobile, address, and primary document ID (Aadhaar/Voter).", desc: "Upload KYC documents." },
            { label: "Submit profile. System automatically links profile ID with database." }
          ],
          note: "KYC verification is required before disbursing any loan."
        },
        {
          icon: "💰",
          title: "Approve Loan Request",
          steps: [
            { label: "Go to Loans > Pending Approvals.", desc: "Click request to inspect details." },
            { label: "Verify member loan eligibility and repayment score.", desc: "Cross-check savings balance and current outstandings." },
            { label: "Click 'Approve' to proceed to disbursal phase." }
          ],
          note: "Maturity details and EMI schedules are auto-generated upon approval."
        },
        {
          icon: "📍",
          title: "Agent Live Location Tracking",
          steps: [
            { label: "Select 'Live Map' from the side panel.", desc: "This renders a real-time tracking interface." },
            { label: "Observe indicators for field staff status.", desc: "Active agents show as green; offline as grey." },
            { label: "Hover over indicators to see current collections and last contact." }
          ],
          note: "Agents must toggle their status to 'On Duty' in their mobile app to broadcast location."
        },
        {
          icon: "📨",
          title: "Send Portal Alerts",
          steps: [
            { label: "Open the 'Members' page and search customer.", desc: "You can filter by loan status or past dues." },
            { label: "Select member profile to inspect communication panel.", desc: "Select 'Send Reminder SMS'." },
            { label: "Choose reminder template and tap compile. SMS will fire from agent outbox." }
          ]
        }
      ]
    },
    collectionAgent: {
      title: "Collection Agent Guide",
      desc: "For field collection agents. Learn how to navigate your daily route, log payments, deposit collected cash, toggle online duty status, and handle offline synchronization.",
      lessons: [
        {
          icon: "🚀",
          title: "Mobile App Access",
          steps: [
            { label: "Download MicroFlow Pro from your manager's shared link.", desc: "Ensure location permissions are allowed." },
            { label: "Enter your registered credentials.", desc: "Allow automatic SMS/phone access." },
            { label: "Access your dashboard to check today's collection targets." }
          ]
        },
        {
          icon: "🔘",
          title: "Toggle Shift Duty Status",
          steps: [
            { label: "Locate 'Duty Toggle' on the dashboard header.", desc: "Slide or tap to switch state." },
            { label: "Confirm 'Duty ON' to initiate tracking session.", desc: "Confirm GPS state is active." },
            { label: "When completing your shift, toggle 'Duty OFF' to stop tracking." }
          ],
          note: "Your live route data is broadcasted to the manager portal only while Duty is ON."
        },
        {
          icon: "💰",
          title: "Collect Weekly/Daily EMIs",
          steps: [
            { label: "Go to 'Today's Collection' tab.", desc: "This lists active collections for your route." },
            { label: "Select customer invoice to open details.", desc: "Select payment mode: Cash, UPI, or Bank." },
            { label: "Enter collection amount and click 'Submit Payment'.", desc: "A receipt SMS is automatically sent to the customer." }
          ]
        },
        {
          icon: "⚡",
          title: "Offline Synced Collection",
          steps: [
            { label: "Proceed with collection as usual, even without network.", desc: "App secures credentials locally." },
            { label: "Check the local database queue badge.", desc: "Badge indicates number of offline entries." },
            { label: "Reconnect to network. Queue will sync automatically to cloud database." }
          ],
          note: "Never log out of the application while there are pending unsynced payments."
        }
      ]
    },
    customer: {
      title: "Customer App Guide",
      desc: "For customers (members). Learn how to check your loan schedule, inspect outstanding savings balance, download statement PDFs, and make secure UPI payments.",
      lessons: [
        {
          icon: "📱",
          title: "Sign In via OTP",
          steps: [
            { label: "Open the Customer App on your mobile device.", desc: "Enter your registered phone number." },
            { label: "Wait for the SMS OTP verification code.", desc: "OTP arrives within 30 seconds." },
            { label: "Submit OTP to verify profile." }
          ]
        },
        {
          icon: "📋",
          title: "Download Loan Statement PDF",
          steps: [
            { label: "Navigate to the 'Active Loans' tab.", desc: "A list of your current loans will appear." },
            { label: "Select your active loan to open details.", desc: "Tap 'Download Statement'." },
            { label: "The statement PDF downloads to your device storage." }
          ],
          note: "The statement shows paid EMIs, interest rate, outstanding amount, and next due date."
        },
        {
          icon: "💰",
          title: "Check Savings Ledger",
          steps: [
            { label: "Select the 'My Savings' page from bottom menu.", desc: "This shows total accumulated deposits." },
            { label: "Verify interest yield rates and maturity date.", desc: "Scroll down to see transaction log." },
            { label: "Compare agent receipts with listed deposits." }
          ]
        }
      ]
    }
  },

  // ──────────────────────────────────────────────────────────────────────────
  // HINDI / हिंदी
  // ──────────────────────────────────────────────────────────────────────────
  hi: {
    common: {
      allGuides: "सभी मार्गदर्शिकाएँ",
      backToHome: "होम",
      documentation: "दस्तावेज़ (Docs)",
      quickLinks: "त्वरित लिंक्स",
      portalGuides: "पोर्टल गाइड",
      watchVideo: "वीडियो देखें",
      openGuide: "गाइड खोलें",
      stepsTitle: "चरण-दर-चरण मार्गदर्शिका",
      lessons: "पाठ",
      portals: "पोर्टल्स",
      youtube: "यूट्यूब",
      selectPortal: "अपना पोर्टल चुनें",
      openGuideAction: "गाइड खोलें",
      subscribe: "सब्सक्राइब",
      popularGuides: "लोकप्रिय गाइड्स",
      youtubeCtaTitle: "वीडियो ट्यूटोरियल उपलब्ध हैं",
      youtubeCtaDesc: "हर विषय के लिए विस्तृत वीडियो ट्यूटोरियल। सरल, आसान चरणों में समझाया गया है। नए वीडियो की जानकारी पाने के लिए हमारे यूट्यूब चैनल को सब्सक्राइब करें।",
    },
    home: {
      title: "दस्तावेज़",
      subtitle: "वीडियो ट्यूटोरियल के साथ पोर्टल-वार गाइड",
      desc: "माइक्रोफ्लो प्रो — प्रत्येक पोर्टल के लिए पूर्ण मार्गदर्शिका। अपने सुक्ष्म वित्त (माइक्रोफाइनेंस) संचालन को प्रबंधित करने के लिए वीडियो देखें और निर्देशों का पालन करें।",
      portals: {
        admin: {
          title: "एग्जीक्यूटिव एडमिन (मुख्य एडमिन)",
          desc: "संगठन सेटअप, शाखा प्रबंधन, स्टाफ की देखरेख, और विस्तृत रिपोर्ट/एनालिटिक्स का नियंत्रण।"
        },
        manager: {
          title: "शाखा प्रबंधक (Branch Manager)",
          desc: "अपनी विशिष्ट शाखा के संग्रह (Collection), ऋण स्वीकृतियों (Loan Approvals) और बचत का प्रबंधन करें।"
        },
        agent: {
          title: "संग्रह एजेंट (Field Agent)",
          desc: "दैनिक संग्रह ट्रैकिंग, ड्यूटी चालू/बंद, लाइव लोकेशन और एसएमएस अलर्ट के लिए मार्गदर्शिका।"
        },
        customer: {
          title: "ग्राहक एप (Customer App)",
          desc: "ग्राहकों के लिए अपने ऋण (Loans), बचत, हालिया भुगतान इतिहास देखने और स्टेटमेंट डाउनलोड करने की गाइड।"
        }
      },
      topics: [
        { label: "📱 ऐप डाउनलोड और लॉगिन", path: "/docs/customer" },
        { label: "👤 नया सदस्य कैसे जोड़ें", path: "/docs/collection-agent" },
        { label: "💰 दैनिक संग्रह की प्रक्रिया", path: "/docs/collection-agent" },
        { label: "📊 लोन स्टेटमेंट PDF निकालना", path: "/docs/customer" },
        { label: "🛡️ टीम, गतिविधि और ऑडिट लॉग", path: "/docs/executive-admin" },
        { label: "📨 एसएमएस अलर्ट सेट करना", path: "/docs/executive-admin" },
        { label: "📍 एजेंट लाइव ट्रैकिंग", path: "/docs/branch-manager" },
        { label: "🔐 पासवर्ड रीसेट करना", path: "/docs/executive-admin" }
      ]
    },
    executiveAdmin: {
      title: "मुख्य एडमिन गाइड (Executive Admin)",
      desc: "मुख्य एडमिन (Executive Admin) के रूप में आप अपने संगठन का पूरा मालिक होते हैं — इसे रजिस्टर करना, ब्रांडिंग करना, प्लान और सीमा तय करना, स्टाफ और सदस्य जोड़ना, लोन और बचत चलाना, और एसएमएस सेट करना। यह गाइड हर फीचर को कवर करता है।",
      lessons: [
        {
          icon: "🚀",
          title: "संगठन रजिस्ट्रेशन (Organization Registration)",
          steps: [
            { label: "साइन इन स्क्रीन पर 'Create Organization' पर टैप करें।", desc: "Create Account फॉर्म खुलेगा — 'Set up your organization in minutes'।" },
            { label: "6 अनिवार्य फ़ील्ड्स भरें।", desc: "संगठन का नाम, अपना पूरा नाम, ईमेल, 10 अंकों का फ़ोन, पासवर्ड (कम से कम 8 अक्षर) और पासवर्ड कन्फर्म करें।" },
            { label: "नियम स्वीकार करें और 'Create Organization' दबाएं।", desc: "एक चेकबॉक्स से आप Terms of Service और Privacy Policy स्वीकार करते हैं।" },
            { label: "अपना ईमेल वेरीफाई करें, फिर साइन इन करें।", desc: "हम आपके ईमेल पर एक वेरिफिकेशन लिंक भेजते हैं। उस पर क्लिक करें, फिर साइन इन करें — आपका संगठन अपने आप 14 दिन के फ्री ट्रायल के साथ बन जाता है।" }
          ],
          note: "आपका अकाउंट मुख्य एडमिन (Executive Admin) के रूप में बनता है। साइनअप पर कोई प्लान नहीं चुना जाता — आप 14 दिन के ट्रायल पर शुरू होते हैं (10 ब्रांच, 5 स्टाफ, 100 सदस्य तक)।"
        },
        {
          icon: "🏠",
          title: "पहला लॉगिन और My Org डैशबोर्ड",
          steps: [
            { label: "साइन इन करें तो आपका My Org डैशबोर्ड खुलेगा।", desc: "यह आपके संगठन का होम है — यहाँ सब कुछ का एक झलक मिलता है।" },
            { label: "Overview के आँकड़े देखें।", desc: "सदस्य (Members), स्टाफ, एक्टिव लोन, कुल वितरित (Disbursed), बकाया (Outstanding), और कुल लोन एक नज़र में।" },
            { label: "Quick Actions का उपयोग करें।", desc: "भुगतान लें (Collect Payment), UPI वेरीफाई, स्टाफ जोड़ें, नया सदस्य, नया लोन, नई बचत, और शाखाएं।" }
          ],
          note: "कभी भी वापस आने के लिए ऊपर दाईं ओर 'My Org' पर टैप करें। नए आँकड़ों के लिए नीचे से ऊपर खींचें (refresh)।"
        },
        {
          icon: "🎨",
          title: "संगठन प्रोफाइल और ब्रांडिंग",
          steps: [
            { label: "Organization Settings खोलें।", desc: "डैशबोर्ड से 'Edit Organization Settings' पर टैप करें, या Settings → Organization Settings पर जाएं।" },
            { label: "अपनी प्रोफाइल अपडेट करें।", desc: "संगठन का नाम और Slug (URL में उपयोग होता है, जैसे my-mfi) बदलें। केवल slug अनूठा (unique) होना चाहिए।" },
            { label: "अपना लोगो अपलोड करें।", desc: "लोगो बॉक्स पर टैप करें और 512×512 इमेज चुनें। यह आपके संगठन के असेट्स में अपलोड होता है और सभी स्टाफ पोर्टल्स पर दिखता है।" },
            { label: "अपने ब्रांड कलर सेट करें।", desc: "Primary और Accent कलर (hex, जैसे #6366F1) डालें। थीम आपके संगठन के हर पोर्टल पर सिंक हो जाती है।" }
          ],
          note: "लोगो और ब्रांड कलर सभी पोर्टल्स पर सिंक होने में कुछ मिनट ले सकते हैं।"
        },
        {
          icon: "💳",
          title: "प्लान, स्थिति और सीमा (Plan, Status & Limits)",
          steps: [
            { label: "अपने संगठन का विवरण या सेटिंग पेज खोलें।", desc: "डैशबोर्ड से ऑर्ग कार्ड पर टैप करें, या 'Edit Organization Settings'।" },
            { label: "प्लान बदलें।", desc: "प्लान बैज (Free / Basic / Pro / Enterprise) पर टैप करें और शीट से प्लान चुनें।" },
            { label: "स्थिति (Status) बदलें।", desc: "स्टेटस चिप पर टैप करके Activate, Suspend, या Trial सेट करें। Suspended ऑर्ग एक्टिव उपयोग से छिप जाता है।" },
            { label: "अपनी प्लान सीमा सेट करें।", desc: "Plan Limits के अंतर्गत Max Branches, Max Staff, और Max Members सेट करें। यूज़ेज बार दिखाते हैं कि आप हर सीमा के कितना पास हैं।" }
          ],
          note: "अपने 14 दिन के ट्रायल में आपको 10 ब्रांच / 5 स्टाफ / 100 सदस्य मिलते हैं। अपग्रेड करने पर ये कैप बढ़ जाते हैं।"
        },
        {
          icon: "⚙️",
          title: "सेटिंग्स अवलोकन (Settings Overview)",
          steps: [
            { label: "मेनू से Settings खोलें।", desc: "पाँच सेक्शन दिखते हैं: Account & Preferences, Organization Controls, System Connectivity, Security & Compliance, Utilities & Support।" },
            { label: "Account & Preferences।", desc: "प्रोफाइल (नाम, फ़ोन, ईमेल, पासवर्ड), डार्क मोड, बायोमेट्रिक लॉगिन, पुश अलर्ट, और AI असिस्टेंट टॉगल।" },
            { label: "Organization Controls (केवल एडमिन)।", desc: "Organization Settings (ब्रांडिंग, कानूनी, पता) और Loan & Savings Products (योजनाएं, दरें, सीमा)।" },
            { label: "System Connectivity (केवल एडमिन)।", desc: "Integrations — SMS, UPI, WhatsApp, SMTP, Razorpay, और PhonePe कनेक्ट करें।" },
            { label: "Security & Compliance।", desc: "Security Shield & Activity Logs, 2FA, पासवर्ड पॉलिसी, ऑटो-लॉगआउट, और Google Drive बैकअप।" }
          ],
          note: "ब्रांडिंग और प्लान लिमिट डैशबोर्ड से खुले Organization Settings के अंतर्गत भी मिलते हैं।"
        },
        {
          icon: "👥",
          title: "स्टाफ जोड़ें और यूज़र्स प्रबंधित करें",
          steps: [
            { label: "Users खोलें।", desc: "Quick Actions से 'Add Staff' पर टैप करें, या Users पेज पर जाएं।" },
            { label: "नया यूज़र बनाएं।", desc: "/users/new पर जाएं और नाम, ईमेल, फ़ोन, और भूमिका (Manager या Collection Agent) डालें।" },
            { label: "यूज़र सूची देखें।", desc: "Users पेज में सबकी सूची है जिसमें रोल फ़िल्टर (Admin, Manager, Agent) और नाम/ईमेल से खोज है।" },
            { label: "टू-फैक्टर ऑथ (2FA) लागू करें।", desc: "Security & Compliance → Two-Factor Authentication में 2FA लागू करें और विधि (Authenticator ऐप या SMS) रोल के हिसाब से चुनें।" }
          ],
          note: "स्टाफ उसी ईमेल से साइन इन करते हैं जो आप रजिस्टर करते हैं — पहली लॉगिन पर वे अपना पासवर्ड सेट करते हैं।"
        },
        {
          icon: "🧑‍🤝‍🧑",
          title: "सदस्य ऑनबोर्डिंग (Members / Customers)",
          steps: [
            { label: "सदस्य ऑनबोर्डिंग शुरू करें।", desc: "Quick Actions से 'New Member' पर टैप करें, या Members पेज → Onboard Member।" },
            { label: "सदस्य का विवरण डालें।", desc: "पूरा नाम, सत्यापित मोबाइल, पता, और प्राथमिक दस्तावेज़ ID (आधार / वोटर)।" },
            { label: "KYC दस्तावेज़ अपलोड करें।", desc: "KYC दस्तावेज़ की फोटो अपलोड करें। कोई लोन देने से पहले KYC वेरीफाई होना चाहिए।" },
            { label: "प्रोफाइल सबमिट करें।", desc: "सिस्टम सदस्य को एक यूनिक Member ID के साथ बनाती है जो आपके ऑर्ग से जुड़ता है।" }
          ],
          note: "हर सदस्य के लोन और बचत पेज पर एक SMS Notifications टॉगल होता है — यही उनका एकमात्र SMS ऑप्ट-आउट है।"
        },
        {
          icon: "🏢",
          title: "शाखाएं प्रबंधित करें (Manage Branches)",
          steps: [
            { label: "Branches खोलें।", desc: "Quick Actions से 'Branches' पर टैप करें, या Organization Settings से खोलें।" },
            { label: "शाखा जोड़ें।", desc: "शाखा बनाने के लिए टैप करें और उसका Name, Code, और स्थान (zone / district) डालें।" },
            { label: "शाखा सूची देखें।", desc: "आपके ऑर्ग विवरण पेज में सभी शाखाएं उनके कोड और active/suspended स्थिति के साथ दिखती हैं।" },
            { label: "एक मैनेजर नियुक्त करें।", desc: "हर शाखा Users में आपके द्वारा आमंत्रित किसी Branch Manager से जुड़ी होती है।" }
          ],
          note: "ब्रांच कोड आपके ऑर्ग के भीतर यूनिक होते हैं और रिपोर्ट व कलेक्शन फ़िल्टर करने में उपयोग होते हैं।"
        },
        {
          icon: "💰",
          title: "लोन — बनाएं और ट्रैक करें",
          steps: [
            { label: "New Loan खोलें।", desc: "Quick Actions से 'New Loan' पर टैप करें ('Deploy Capital' पेज)।" },
            { label: "लोन का विवरण डालें।", desc: "Borrower (सदस्य) चुनें, Principal (₹1K–₹10L), ब्याज (APR % या निश्चित राशि, प्रति day/week/month/year), Interest Logic (flat या reducing), पहली किस्त की तारीख, Tenure, और Collection Type (Daily/Weekly/Monthly/Yearly)।" },
            { label: "लाइव सारांश देखें।", desc: "Financial Summary अनुमानित किस्त, कुल ब्याज, और पूरा amortization (EMI) प्रीव्यू सेव करने से पहले दिखाता है।" },
            { label: "एक्टिव लोन ट्रैक करें।", desc: "लोन सीधे (active) बनते हैं — कोई अनुमोदन गेट नहीं। लोन विवरण में बकाया, देय अलर्ट (OVERDUE / DUE TODAY), EMI टाइमलाइन, और Loan Intelligence दिखता है।" },
            { label: "लोन प्रबंधित करें।", desc: "'…' मेनू से: Edit, Mark Defaulted, Reactivate, Restructure, Freeze Skipped EMIs, या Delete।" }
          ],
          note: "EMI की स्थिति में PAID, DUE, OVERDUE, WAIVED, PENDING, और FROZEN शामिल हैं। खुले लोन पर Collect / Settle / Reminder एक्शन दिखते हैं।"
        },
        {
          icon: "🏦",
          title: "बचत — योजनाएं प्रबंधित करें (Savings)",
          steps: [
            { label: "New Savings Plan खोलें।", desc: "Quick Actions से 'New Savings' पर टैप करें।" },
            { label: "योजना का विवरण डालें।", desc: "सदस्य चुनें, Collection Cycle (Daily/Weekly/Monthly/Yearly), Installment Amount (₹10–₹50K), Start Date, Tenure, Maturity Amount, और Premature Penalty %।" },
            { label: "Wealth Forecast देखें।", desc: "लाइव प्रीव्यू गारंटीड मैच्योरिटी, कुल किस्तें, कुल कैपिटल, और अनुमानित यील्ड दिखाता है।" },
            { label: "जमा (Deposit) और निकासी (Withdraw)।", desc: "कलेक्शन शीट से कभी भी जमा करें। निकासी एक Withdrawal Requests कतार (Pending/Approved/Rejected) में जाती है जहाँ मैनेजर कारण के साथ स्वीकृत या अस्वीकृत करता है।" },
            { label: "वॉल्ट प्रबंधित करें।", desc: "Pause/Resume वॉल्ट, खाता बंद (Close), या (केवल एडमिन) स्थायी रूप से डिलीट करें। बैलेंस और यील्ड-प्रोजेक्शन चार्ट दिखते हैं।" }
          ],
          note: "बचत Principal Protected होती है। समय से पहले निकासी पर वह Penalty % लगता है जो आपने बनाने के समय सेट किया था।"
        },
        {
          icon: "📨",
          title: "एसएमएस और सूचनाएं (SMS & Notifications)",
          steps: [
            { label: "SMS Settings खोलें।", desc: "Settings → Integrations → Communications टैब → Local SMS। यह SMS Settings पेज खोलता है (केवल एडमिन)।" },
            { label: "ऑटो-रसीद चालू करें।", desc: "'SMS on Collection' और 'SMS on Savings Deposit' डिफ़ॉल्ट ON हैं — हर लेन-देन के बाद ग्राहक को रसीद मिलती है।" },
            { label: "EMI रिमाइंडर चालू करें।", desc: "'Due EMI Reminders' (डिफ़ॉल्ट OFF) टॉगल करें और दैनिक Reminder Time सेट करें। टेम्पलेट {name}, {amount}, {loan_id}, {balance} का उपयोग करते हैं।" },
            { label: "SIM स्लॉट चुनें।", desc: "SIM & Outbox के अंतर्गत चुनें कि SMS कौन सा डिवाइस SIM भेजे, टेस्ट SMS भेजें, और भेजे गए SMS इतिहास (आखिरी 200) देखें।" },
            { label: "सदस्य-वार ऑप्ट-आउट।", desc: "किसी भी लोन या बचत विवरण पेज पर 'SMS Notifications' टॉगल कर उस सदस्य के लिए रिमाइंडर चालू/बंद करें।" }
          ],
          note: "SMS डिवाइस के SIM (native Android plugin) से जाता है — कोई बाहरी SMS गेटवे नहीं। WhatsApp और Email अलग से Integrations में सेट होते हैं।"
        },
        {
          icon: "💸",
          title: "भुगतान लें और UPI वेरीफाई करें",
          steps: [
            { label: "Collect Payment खोलें।", desc: "Quick Actions से 'Collect Payment' पर टैप करके कलेक्शन शुरू करें।" },
            { label: "कलेक्शन दर्ज करें।", desc: "सदस्य/लोन चुनें, राशि डालें, मोड (Cash, UPI, या Bank) चुनें, और सबमिट करें। सक्षम होने पर रसीद SMS अपने आप जाती है।" },
            { label: "UPI भुगतान वेरीफाई करें।", desc: "Quick Actions से 'UPI Verify' पर टैप करके ग्राहक के UPI रेफरेंस को अपेक्षित भुगतान से मिलाएं।" }
          ],
          note: "कलेक्शन डैशबोर्ड की Recent Collections में तुरंत दिखते हैं और क्लाउड में सिंक होते हैं।"
        },
        {
          icon: "🛡️",
          title: "टीम, गतिविधि और ऑडिट लॉग",
          steps: [
            { label: "अपना ऑर्ग विवरण पेज खोलें।", desc: "डैशबोर्ड पर किसी भी ऑर्ग कार्ड पर टैप करें ताकि पूरा सारांश दिखे।" },
            { label: "Team Members देखें।", desc: "Team टाइल सभी स्टाफ को रोल-रंगीन अवतार के साथ दिखाती है, नाम/ईमेल खोज और रोल फ़िल्टर के साथ।" },
            { label: "Recent Activity जांचें।", desc: "Activity टाइल क्रियाओं (auth, loan, payment, savings, member) का लॉग दिखाती है — किसने क्या और कब किया।" },
            { label: "Security & Activity Logs खोलें।", desc: "Settings → Security & Compliance में System Activity Logs खोलें और ऑडिट रिटेंशन, पासवर्ड पॉलिसी, और Google Drive बैकअप सेट करें।" }
          ],
          note: "ऑडिट लॉग हर बदलाव का पता लगाने में मदद करते हैं — समीक्षा या विवाद के समय उपयोगी।"
        }
      ]
    },
    branchManager: {
      title: "शाखा प्रबंधक गाइड (Branch Manager)",
      desc: "शाखा प्रबंधक के रूप में, आप स्थानीय शाखा के इंचार्ज हैं। नए ग्राहकों को जोड़ना, एजेंटों के काम की निगरानी करना, कैश कलेक्शन को ऑडिट करना, और लोन पास करना आपकी मुख्य जिम्मेदारी है।",
      lessons: [
        {
          icon: "🚀",
          title: "शुरुआत करना — मैनेजर लॉगिन",
          steps: [
            { label: "मुख्य एडमिन द्वारा भेजे गए निमंत्रण (Invite) ईमेल को खोलें।" },
            { label: "पासवर्ड सेट करें और अपने खाते में साइन इन करें।" },
            { label: "शाखा डैशबोर्ड देखें - यहाँ दैनिक संग्रह और लक्ष्यों की प्रगति दिखती है।" }
          ]
        },
        {
          icon: "👥",
          title: "नया ग्राहक जोड़ना (Member Onboarding)",
          steps: [
            { label: "Members > Onboard Member विकल्प पर जाएं।", desc: "सत्यापन के लिए ग्राहक के दस्तावेज़ साथ रखें।" },
            { label: "ग्राहक का नाम, पता, मोबाइल नंबर और आधार/वोटर आईडी दर्ज करें।", desc: "KYC दस्तावेज़ों की फोटो अपलोड करें।" },
            { label: "सुरक्षित (Submit) करें। सिस्टम सदस्य को स्वचालित रूप से एक खाता संख्या (Member ID) अलॉट कर देगा।" }
          ],
          note: "लोन देने से पहले ग्राहक का केवाईसी (KYC) सत्यापन होना आवश्यक है।"
        },
        {
          icon: "💰",
          title: "लोन अनुरोध स्वीकृत करना (Approve Loan)",
          steps: [
            { label: "Loans > Pending Approvals पर जाएं।", desc: "ग्राहक की लोन फाइल और उसके दस्तावेज़ देखें।" },
            { label: "ग्राहक की पिछली किस्त चुकाने का इतिहास और बचत का स्तर जांचें।" },
            { label: "सब ठीक होने पर 'Approve' (स्वीकार) बटन दबाएं ताकि पैसे बांटे जा सकें।" }
          ],
          note: "लोन पास होते ही किस्त चुकाने की तारीखें (EMI Schedule) सिस्टम द्वारा स्वचालित रूप से तैयार हो जाती हैं।"
        },
        {
          icon: "📍",
          title: "एजेंटों की लाइव लोकेशन देखना",
          steps: [
            { label: "साइड पैनल से 'Live Map' खोलें।", desc: "यह मानचित्र पर लाइव ट्रैकिंग दिखाता है।" },
            { label: "मैप पर अपने फील्ड एजेंटों की स्थिति देखें।", desc: "हरे रंग का चिन्ह मतलब एक्टिव ड्यूटी, ग्रे का मतलब ऑफ-ड्यूटी।" },
            { label: "चिन्ह पर क्लिक करके देखें कि एजेंट ने आज कितना कलेक्शन किया है।" }
          ],
          note: "एजेंट का लोकेशन तभी दिखेगा जब उसने अपने मोबाइल ऐप में 'Duty ON' किया हो और उनका जीपीएस चालू हो।"
        }
      ]
    },
    collectionAgent: {
      title: "संग्रह एजेंट गाइड (Field Agent)",
      desc: "फील्ड एजेंटों के लिए विस्तृत गाइड। किस्तें कैसे कलेक्ट करें, बिना इंटरनेट के काम कैसे करें, रसीद कैसे भेजें और क्षेत्र में मैप का उपयोग कर ग्राहकों तक कैसे पहुंचें।",
      lessons: [
        {
          icon: "🚀",
          title: "मोबाइल ऐप में लॉगिन",
          steps: [
            { label: "अपने मैनेजर द्वारा शेयर किए गए लिंक से ऐप डाउनलोड करें।", desc: "ऐप को जीपीएस और एसएमएस की अनुमति दें।" },
            { label: "अपना रजिस्टर्ड आईडी (ईमेल) और पासवर्ड डालें।" },
            { label: "डैशबोर्ड पर जाकर आज की कलेक्शन सूची और रूट देखें।" }
          ]
        },
        {
          icon: "🔘",
          title: "ड्यूटी चालू/बंद करना (Duty ON/OFF)",
          steps: [
            { label: "डैशबोर्ड के ऊपर दिए गए 'Duty Toggle' बटन को ढूंढें।" },
            { label: "क्षेत्र में काम शुरू करने से पहले Duty ON करें।", desc: "चेक करें की जीपीएस की लाइट चालू है।" },
            { label: "काम खत्म होने पर 'Duty OFF' कर दें ताकि बैटरी बचे और लोकेशन ट्रैक होना बंद हो।" }
          ],
          note: "ड्यूटी ऑन होने पर ही आपकी कलेक्शन लोकेशन मैनेजर को दिखेगी।"
        },
        {
          icon: "💰",
          title: "दैनिक किस्तें (EMI) वसूलना",
          steps: [
            { label: "'Today's Collection' (आज का कलेक्शन) टैब पर जाएं।", desc: "यहाँ उन सदस्यों की सूची है जिनसे आज पैसे लेने हैं।" },
            { label: "ग्राहक के नाम पर क्लिक करें और लोन की राशि जांचें।" },
            { label: "वसूल की गई राशि लिखें, कलेक्शन मोड चुनें (नकद/UPI) और 'Collect' बटन दबाएं।", desc: "भुगतान पूरा होते ही रसीद का एसएमएस ग्राहक को तुरंत मिल जाएगा।" }
          ]
        },
        {
          icon: "⚡",
          title: "ऑफलाइन काम करना (Offline Mode)",
          steps: [
            { label: "इंटरनेट न होने पर भी सामान्य रूप से कलेक्शन जारी रखें।" },
            { label: "डैशबोर्ड पर 'Offline Queue' का सिंक बैज देखें।", desc: "यह बिना सिंक हुए भुगतानों की संख्या दिखाता है।" },
            { label: "जैसे ही मोबाइल में इंटरनेट वापस आए, सिंक बैज दबाएं। सारा डाटा सर्वर पर सुरक्षित चला जाएगा।" }
          ],
          note: "जब तक आपका ऑफलाइन डाटा पूरी तरह सिंक (Sync) न हो जाए, ऐप से लॉग आउट न करें।"
        }
      ]
    },
    customer: {
      title: "ग्राहक गाइड (Customer App)",
      desc: "ग्राहकों के लिए गाइड। अपने मोबाइल पर अपनी जमा पूंजी देखना, चुकाई गई किस्तों की लिस्ट देखना और लोन स्टेटमेंट का पीडीएफ डाउनलोड करना सीखें।",
      lessons: [
        {
          icon: "📱",
          title: "ओटीपी (OTP) से लॉगिन करना",
          steps: [
            { label: "अपने मोबाइल पर 'MicroFlow Pro' ग्राहक ऐप खोलें।" },
            { label: "अपना पंजीकृत मोबाइल नंबर दर्ज करें और सबमिट करें।" },
            { label: "मोबाइल पर प्राप्त 6 अंकों का ओटीपी कोड लिखें और लॉगिन करें।" }
          ]
        },
        {
          icon: "📋",
          title: "लोन स्टेटमेंट डाउनलोड करना",
          steps: [
            { label: "ऐप में 'My Loans' (मेरे लोन) विकल्प पर जाएं।" },
            { label: "अपने एक्टिव लोन का चयन करें।" },
            { label: "'Download Statement' (स्टेटमेंट डाउनलोड करें) बटन पर क्लिक करें।", desc: "पीडीएफ फ़ाइल आपके फोन की स्टोरेज में सुरक्षित हो जाएगी।" }
          ],
          note: "स्टेटमेंट पीडीएफ में चुकाई गई रसीदें, बकाया राशि, ब्याज और अगली तारीख आदि की पूरी जानकारी होती है।"
        },
        {
          icon: "💰",
          title: "अपनी बचत (Savings) का बैलेंस जांचना",
          steps: [
            { label: "बचत सूची देखने के लिए 'My Savings' टैब पर जाएं।" },
            { label: "कुल जमा राशि, ब्याज की दर और मैच्योरिटी की तारीख देखें।" },
            { label: "एजेंट को दिए गए पैसों और रसीदों का मिलान करें।" }
          ]
        }
      ]
    }
  },

  // ──────────────────────────────────────────────────────────────────────────
  // BENGALI / বাংলা
  // ──────────────────────────────────────────────────────────────────────────
  bn: {
    common: {
      allGuides: "সব নির্দেশিকা",
      backToHome: "হোম",
      documentation: "নথিপত্র (Docs)",
      quickLinks: "দ্রুত লিঙ্কসমূহ",
      portalGuides: "পোর্টাল গাইড",
      watchVideo: "ভিডিও দেখুন",
      openGuide: "গাইড খুলুন",
      stepsTitle: "ধাপে ধাপে নির্দেশিকা",
      lessons: "অধ্যায়",
      portals: "পোর্টাল",
      youtube: "ইউটিউব",
      selectPortal: "আপনার পোর্টাল নির্বাচন করুন",
      openGuideAction: "গাইড খুলুন",
      subscribe: "সাবস্ক্রাইব",
      popularGuides: "জনপ্রিয় গাইডসমূহ",
      youtubeCtaTitle: "ভিডিও টিউটোরিয়াল উপলব্ধ",
      youtubeCtaDesc: "প্রতিটি বিষয়ের জন্য বিস্তারিত ভিডিও টিউটোরিয়াল। সহজ ও সরল ধাপে ব্যাখ্যা করা হয়েছে। নতুন ভিডিওর আপডেট পেতে আমাদের ইউটিউব চ্যানেলটি সাবস্ক্রাইব করুন।",
    },
    home: {
      title: "নথিপত্র",
      subtitle: "ভিডিও টিউটোরিয়াল সহ পোর্টাল-ভিত্তিক গাইড",
      desc: "মাইক্রোফ্লো প্রো — প্রতিটি পোর্টালের জন্য সম্পূর্ণ নির্দেশিকা। আপনার ক্ষুদ্র ঋণ (মাইক্রোফাইন্যান্স) পরিচালনা করতে ভিডিও দেখুন এবং নির্দেশাবলী অনুসরণ করুন।",
      portals: {
        admin: {
          title: "এক্সিকিউটিভ অ্যাডমিন (মূল অ্যাডমিন)",
          desc: "অর্গানাইজেশন সেটআপ, ব্রাঞ্চ পরিচালনা, স্টাফদের তদারকি, ঋণ ও সঞ্চয় পরিচালনা এবং এসএমএস সেটিংসের সম্পূর্ণ নিয়ন্ত্রণ।"
        },
        manager: {
          title: "শাখা ব্যবস্থাপক (Branch Manager)",
          desc: "আপনার নির্দিষ্ট শাখার কালেকশন, লোন অনুমোদন, সঞ্চয় বা ডিপোজিট পরিচালনা এবং স্টাফ ট্র্যাকিং।"
        },
        agent: {
          title: "কালেকশন এজেন্ট (Field Agent)",
          desc: "দৈনিক কিস্তি আদায় (Collection), ডিউটি অন/অফ, লাইভ লোকেশন এবং গ্রাহকের মোবাইলে এসএমএস অ্যালার্টের গাইড।"
        },
        customer: {
          title: "গ্রাহক অ্যাপ (Customer App)",
          desc: "গ্রাহকদের জন্য কিস্তির খতিয়ান, সঞ্চয়ের ব্যালেন্স, সাম্প্রতিক লেনদেন দেখা এবং স্টেটমেন্ট ডাউনলোডের গাইড।"
        }
      },
      topics: [
        { label: "📱 অ্যাপ ডাউনলোড ও লগইন", path: "/docs/customer" },
        { label: "👤 নতুন মেম্বার কীভাবে যুক্ত করবেন", path: "/docs/collection-agent" },
        { label: "💰 দৈনিক কালেকশন প্রক্রিয়া", path: "/docs/collection-agent" },
        { label: "📊 লোন স্টেটমেন্ট PDF বের করা", path: "/docs/customer" },
        { label: "🛡️ টিম, কার্যকলাপ ও অডিট লগ", path: "/docs/executive-admin" },
        { label: "📨 এসএমএস অ্যালার্ট সেট করা", path: "/docs/executive-admin" },
        { label: "📍 এজেন্টের লাইভ লোকেশন ট্র্যাকিং", path: "/docs/branch-manager" },
        { label: "🔐 পাসওয়ার্ড রিসেট করা", path: "/docs/executive-admin" }
      ]
    },
    executiveAdmin: {
      title: "মূল অ্যাডমিন গাইড (Executive Admin)",
      desc: "এক্সিকিউটিভ অ্যাডমিন (Executive Admin) হিসেবে আপনি আপনার সংস্থার সম্পূর্ণ মালিক — এটি নিবন্ধন করা, ব্র্যান্ডিং করা, প্ল্যান ও সীমা ঠিক করা, স্টাফ ও সদস্য যোগ করা, ঋণ ও সঞ্চয় পরিচালনা এবং এসএমএস সেট করা। এই গাইডটি প্রতিটি বৈশিষ্ট্য কভার করে।",
      lessons: [
        {
          icon: "🚀",
          title: "সংস্থা নিবন্ধন (Organization Registration)",
          steps: [
            { label: "সাইন ইন স্ক্রিনে 'Create Organization'-এ ট্যাপ করুন।", desc: "Create Account ফর্মটি খুলবে — 'Set up your organization in minutes'।" },
            { label: "৬টি বাধ্যতামূলক ক্ষেত্র পূরণ করুন।", desc: "সংস্থার নাম, আপনার পুরো নাম, ইমেল, ১০-সংখ্যার ফোন, পাসওয়ার্ড (সর্বনিম্ন ৮ অক্ষর) এবং পাসওয়ার্ড নিশ্চিত করুন।" },
            { label: "শর্তাবলী গ্রহণ করে 'Create Organization' চাপুন।", desc: "একটি চেকবক্সের মাধ্যমে আপনি Terms of Service এবং Privacy Policy গ্রহণ করেন।" },
            { label: "আপনার ইমেল যাচাই করুন, তারপর সাইন ইন করুন।", desc: "আমরা আপনার ইমেলে একটি যাচাইকরণ লিঙ্ক পাঠাই। সেটিতে ক্লিক করুন, তারপর সাইন ইন করুন — আপনার সংস্থা স্বয়ংক্রিয়ভাবে ১৪ দিনের ফ্রি ট্রায়াল সহ তৈরি হয়।" }
          ],
          note: "আপনার অ্যাকাউন্টটি এক্সিকিউটিভ অ্যাডমিন হিসেবে তৈরি হয়। সাইনআপে কোনো প্ল্যান বাছাই হয় না — আপনি ১৪ দিনের ট্রায়ালে শুরু করেন (সর্বোচ্চ ১০ ব্রাঞ্চ, ৫ স্টাফ, ১০০ সদস্য)।"
        },
        {
          icon: "🏠",
          title: "প্রথম লগইন এবং My Org ড্যাশবোর্ড",
          steps: [
            { label: "সাইন ইন করলে আপনার My Org ড্যাশবোর্ড খুলবে।", desc: "এটি আপনার সংস্থার হোম — এখানে সবকিছুর একটি ঝলক পাওয়া যায়।" },
            { label: "Overview-এর পরিসংখ্যান দেখুন।", desc: "সদস্য (Members), স্টাফ, সক্রিয় ঋণ (Active Loans), মোট বিতরণ (Disbursed), বকেয়া (Outstanding), এবং মোট ঋণ এক নজরে।" },
            { label: "Quick Actions ব্যবহার করুন।", desc: "ভুগতান নিন (Collect Payment), UPI যাচাই, স্টাফ যোগ করুন, নতুন সদস্য, নতুন ঋণ, নতুন সঞ্চয়, এবং শাখাসমূহ।" }
          ],
          note: "যেকোনো সময় ফিরে আসতে উপরে ডানদিকে 'My Org'-এ ট্যাপ করুন। নতুন সংখ্যার জন্য নিচ থেকে উপরে টানুন (refresh)।"
        },
        {
          icon: "🎨",
          title: "সংস্থার প্রোফাইল ও ব্র্যান্ডিং",
          steps: [
            { label: "Organization Settings খুলুন।", desc: "ড্যাশবোর্ড থেকে 'Edit Organization Settings'-এ ট্যাপ করুন, অথবা Settings → Organization Settings-এ যান।" },
            { label: "আপনার প্রোফাইল আপডেট করুন।", desc: "সংস্থার নাম এবং Slug (URL-এ ব্যবহৃত হয়, যেমন my-mfi) বদলান। কেবল slug অনন্য (unique) হতে হবে।" },
            { label: "আপনার লোগো আপলোড করুন।", desc: "লোগো বাক্সে ট্যাপ করে ৫১২×৫১২ ছবি বাছুন। এটি আপনার সংস্থার অ্যাসেটে আপলোড হয় এবং সব স্টাফ পোর্টালে দেখা যায়।" },
            { label: "আপনার ব্র্যান্ড কালার সেট করুন।", desc: "Primary এবং Accent কালার (hex, যেমন #6366F1) লিখুন। থিম আপনার সংস্থার প্রতিটি পোর্টালে সিঙ্ক হয়ে যায়।" }
          ],
          note: "লোগো এবং ব্র্যান্ড কালার সব পোর্টালে সিঙ্ক হতে কয়েক মিনিট সময় নিতে পারে।"
        },
        {
          icon: "💳",
          title: "প্ল্যান, স্থিতি ও সীমা (Plan, Status & Limits)",
          steps: [
            { label: "আপনার সংস্থার বিবরণ বা সেটিংস পেজ খুলুন।", desc: "ড্যাশবোর্ড থেকে অর্গ কার্ডে ট্যাপ করুন, অথবা 'Edit Organization Settings'।" },
            { label: "প্ল্যান বদলান।", desc: "প্ল্যান ব্যাজ (Free / Basic / Pro / Enterprise) এ ট্যাপ করে শিট থেকে প্ল্যান বাছুন।" },
            { label: "স্থিতি (Status) বদলান।", desc: "স্ট্যাটাস চিপে ট্যাপ করে Activate, Suspend, বা Trial সেট করুন। Suspended অর্গ সক্রিয় ব্যবহার থেকে লুকিয়ে যায়।" },
            { label: "আপনার প্ল্যান সীমা সেট করুন।", desc: "Plan Limits-এর অধীনে Max Branches, Max Staff, এবং Max Members সেট করুন। ব্যবহার বারগুলি দেখায় আপনি প্রতিটি সীমার কত কাছাকাছি।" }
          ],
          note: "আপনার ১৪ দিনের ট্রায়ালে আপনি ১০ ব্রাঞ্চ / ৫ স্টাফ / ১০০ সদস্য পান। আপগ্রেড করলে এই ক্যাপ বাড়ে।"
        },
        {
          icon: "⚙️",
          title: "সেটিংস অবলোকন (Settings Overview)",
          steps: [
            { label: "মেনু থেকে Settings খুলুন।", desc: "পাঁচটি বিভাগ দেখা যায়: Account & Preferences, Organization Controls, System Connectivity, Security & Compliance, Utilities & Support।" },
            { label: "Account & Preferences।", desc: "প্রোফাইল (নাম, ফোন, ইমেল, পাসওয়ার্ড), ডার্ক মোড, বায়োমেট্রিক লগইন, পুশ অ্যালার্ট, এবং AI অ্যাসিস্ট্যান্ট টগল।" },
            { label: "Organization Controls (কেবল অ্যাডমিন)।", desc: "Organization Settings (ব্র্যান্ডিং, আইনি, ঠিকানা) এবং Loan & Savings Products (স্কিম, হার, সীমা)।" },
            { label: "System Connectivity (কেবল অ্যাডমিন)।", desc: "Integrations — এসএমএস, UPI, WhatsApp, SMTP, Razorpay, এবং PhonePe সংযুক্ত করুন।" },
            { label: "Security & Compliance।", desc: "Security Shield & Activity Logs, 2FA, পাসওয়ার্ড নীতি, অটো-লগআউট, এবং Google Drive ব্যাকআপ।" }
          ],
          note: "ব্র্যান্ডিং এবং প্ল্যান লিমিট ড্যাশবোর্ড থেকে খোলা Organization Settings-এর অধীনেও পাওয়া যায়।"
        },
        {
          icon: "👥",
          title: "স্টাফ যোগ করুন ও ইউজার পরিচালনা করুন",
          steps: [
            { label: "Users খুলুন।", desc: "Quick Actions থেকে 'Add Staff'-এ ট্যাপ করুন, অথবা Users পেজে যান।" },
            { label: "নতুন ইউজার তৈরি করুন।", desc: "/users/new-এ যান এবং নাম, ইমেল, ফোন, এবং ভূমিকা (Manager বা Collection Agent) লিখুন।" },
            { label: "ইউজার তালিকা দেখুন।", desc: "Users পেজে সবার তালিকা থাকে যাতে রোল ফিল্টার (Admin, Manager, Agent) এবং নাম/ইমেল অনুসন্ধান থাকে।" },
            { label: "টু-ফ্যাক্টর অথ (2FA) প্রয়োগ করুন।", desc: "Security & Compliance → Two-Factor Authentication-এ 2FA প্রয়োগ করুন এবং পদ্ধতি (Authenticator অ্যাপ বা SMS) রোল অনুযায়ী বাছুন।" }
          ],
          note: "স্টাফ সেই ইমেল দিয়ে সাইন ইন করে যা আপনি নিবন্ধন করেন — প্রথম লগইনে তারা নিজের পাসওয়ার্ড সেট করে।"
        },
        {
          icon: "🧑‍🤝‍🧑",
          title: "সদস্য অনবোর্ডিং (Members / Customers)",
          steps: [
            { label: "সদস্য অনবোর্ডিং শুরু করুন।", desc: "Quick Actions থেকে 'New Member'-এ ট্যাপ করুন, অথবা Members পেজ → Onboard Member।" },
            { label: "সদস্যের বিবরণ লিখুন।", desc: "পুরো নাম, যাচাইকৃত মোবাইল, ঠিকানা, এবং প্রাথমিক নথি ID (আধার / ভোটার)।" },
            { label: "KYC নথি আপলোড করুন।", desc: "KYC নথির ছবি আপলোড করুন। কোনো ঋণ দেওয়ার আগে KYC যাচাই হওয়া আবশ্যক।" },
            { label: "প্রোফাইল জমা দিন।", desc: "সিস্টেম সদস্যকে একটি অনন্য Member ID-সহ তৈরি করে যা আপনার অর্গের সাথে যুক্ত থাকে।" }
          ],
          note: "প্রতিটি সদস্যের ঋণ ও সঞ্চয় পেজে একটি SMS Notifications টগল থাকে — এটিই তাদের একমাত্র এসএমএস অপ্ট-আউট।"
        },
        {
          icon: "🏢",
          title: "শাখা পরিচালনা (Manage Branches)",
          steps: [
            { label: "Branches খুলুন।", desc: "Quick Actions থেকে 'Branches'-এ ট্যাপ করুন, অথবা Organization Settings থেকে খুলুন।" },
            { label: "শাখা যোগ করুন।", desc: "শাখা তৈরি করতে ট্যাপ করে তার Name, Code, এবং অবস্থান (zone / district) লিখুন।" },
            { label: "শাখা তালিকা দেখুন।", desc: "আপনার অর্গ বিবরণ পেজে সব শাখা তাদের কোড এবং active/suspended স্থিতি সহ দেখা যায়।" },
            { label: "একজন ম্যানেজার নিয়োগ করুন।", desc: "প্রতিটি শাখা Users-এ আপনার আমন্ত্রিত কোনো Branch Manager-এর সাথে যুক্ত থাকে।" }
          ],
          note: "ব্রাঞ্চ কোড আপনার অর্গের মধ্যে অনন্য হয় এবং রিপোর্ট ও কালেকশন ফিল্টার করতে ব্যবহৃত হয়।"
        },
        {
          icon: "💰",
          title: "ঋণ — তৈরি ও ট্র্যাক করুন",
          steps: [
            { label: "New Loan খুলুন।", desc: "Quick Actions থেকে 'New Loan'-এ ট্যাপ করুন ('Deploy Capital' পেজ)।" },
            { label: "ঋণের বিবরণ লিখুন।", desc: "Borrower (সদস্য) বাছুন, Principal (₹1K–₹10L), সুদ (APR % বা নির্দিষ্ট অঙ্ক, প্রতি day/week/month/year), Interest Logic (flat বা reducing), প্রথম কিস্তির তারিখ, Tenure, এবং Collection Type (Daily/Weekly/Monthly/Yearly)।" },
            { label: "লাইভ সারাংশ দেখুন।", desc: "Financial Summary অনুমিত কিস্তি, মোট সুদ, এবং সম্পূর্ণ amortization (EMI) প্রিভিউ সংরক্ষণের আগে দেখায়।" },
            { label: "সক্রিয় ঋণ ট্র্যাক করুন।", desc: "ঋণ সরাসরি (active) তৈরি হয় — কোনো অনুমোদন গেট নেই। ঋণের বিবরণে বকেয়া, বিলম্ব/আজ-বকেয়া অ্যালার্ট (OVERDUE / DUE TODAY), EMI টাইমলাইন, এবং Loan Intelligence দেখায়।" },
            { label: "ঋণ পরিচালনা করুন।", desc: "'…' মেনু থেকে: Edit, Mark Defaulted, Reactivate, Restructure, Freeze Skipped EMIs, অথবা Delete।" }
          ],
          note: "EMI-এর স্থিতির মধ্যে PAID, DUE, OVERDUE, WAIVED, PENDING, এবং FROZEN অন্তর্ভুক্ত। খোলা ঋণে Collect / Settle / Reminder অ্যাকশন দেখা যায়।"
        },
        {
          icon: "🏦",
          title: "সঞ্চয় — পরিকল্পনা পরিচালনা (Savings)",
          steps: [
            { label: "New Savings Plan খুলুন।", desc: "Quick Actions থেকে 'New Savings'-এ ট্যাপ করুন।" },
            { label: "পরিকল্পনার বিবরণ লিখুন।", desc: "সদস্য বাছুন, Collection Cycle (Daily/Weekly/Monthly/Yearly), Installment Amount (₹10–₹50K), Start Date, Tenure, Maturity Amount, এবং Premature Penalty %।" },
            { label: "Wealth Forecast দেখুন।", desc: "লাইভ প্রিভিউ গ্যারান্টিড ম্যাচুরিটি, মোট কিস্তি, মোট ক্যাপিটাল, এবং অনুমিত ইল্ড দেখায়।" },
            { label: "জমা (Deposit) ও উত্তোলন (Withdraw)।", desc: "কালেকশন শিট থেকে যেকোনো সময় জমা করুন। উত্তোলন একটি Withdrawal Requests কিউ (Pending/Approved/Rejected) তে যায় যেখানে একজন ম্যানেজার কারণসহ অনুমোদন বা প্রত্যাখ্যান করেন।" },
            { label: "ভল্ট পরিচালনা করুন।", desc: "Pause/Resume ভল্ট, অ্যাকাউন্ট বন্ধ (Close), অথবা (কেবল অ্যাডমিন) স্থায়ীভাবে মুছে ফেলুন (Delete)। ব্যালেন্স ও ইল্ড-প্রোজেকশন চার্ট দেখা যায়।" }
          ],
          note: "সঞ্চয় Principal Protected। সময়ের আগে উত্তোলনে সেই Penalty % প্রযোজ্য হয় যা তৈরির সময় সেট করেছিলেন।"
        },
        {
          icon: "📨",
          title: "এসএমএস ও বিজ্ঞপ্তি (SMS & Notifications)",
          steps: [
            { label: "SMS Settings খুলুন।", desc: "Settings → Integrations → Communications ট্যাব → Local SMS। এটি SMS Settings পেজ খোলে (কেবল অ্যাডমিন)।" },
            { label: "অটো-রসিদ চালু করুন।", desc: "'SMS on Collection' এবং 'SMS on Savings Deposit' ডিফল্ট ON — প্রতিটি লেনদেনের পর গ্রাহক রসিদ পান।" },
            { label: "EMI রিমাইন্ডার চালু করুন।", desc: "'Due EMI Reminders' (ডিফল্ট OFF) টগল করুন এবং দৈনিক Reminder Time সেট করুন। টেমপ্লেট {name}, {amount}, {loan_id}, {balance} ব্যবহার করে।" },
            { label: "SIM স্লট বাছুন।", desc: "SIM & Outbox-এর অধীনে বাছুন কোন ডিভাইস SIM এসএমএস পাঠাবে, টেস্ট SMS পাঠান, এবং পাঠানো এসএমএস ইতিহাস (শেষ ২০০) দেখুন।" },
            { label: "সদস্য-ভিত্তিক অপ্ট-আউট।", desc: "যেকোনো ঋণ বা সঞ্চয় বিবরণ পেজে 'SMS Notifications' টগল করে ওই সদস্যের জন্য রিমাইন্ডার চালু/বন্ধ করুন।" }
          ],
          note: "এসএমএস ডিভাইসের SIM (native Android plugin) থেকে যায় — কোনো বাহ্যিক এসএমএস গেটওয়ে নেই। WhatsApp এবং Email আলাদাভাবে Integrations-এ সেট হয়।"
        },
        {
          icon: "💸",
          title: "ভুগতান নিন ও UPI যাচাই করুন",
          steps: [
            { label: "Collect Payment খুলুন।", desc: "Quick Actions থেকে 'Collect Payment'-এ ট্যাপ করে কালেকশন শুরু করুন।" },
            { label: "কালেকশন লিখুন।", desc: "সদস্য/ঋণ বাছুন, অঙ্ক লিখুন, মোড (Cash, UPI, বা Bank) বাছুন, এবং জমা দিন। সক্রিয় থাকলে রসিদ এসএমএস স্বয়ংক্রিয় যায়।" },
            { label: "UPI ভুগতান যাচাই করুন।", desc: "Quick Actions থেকে 'UPI Verify'-এ ট্যাপ করে গ্রাহকের UPI রেফারেন্স প্রত্যাশিত ভুগতানের সাথে মেলান।" }
          ],
          note: "কালেকশন ড্যাশবোর্ডের Recent Collections-এ সাথে সাথে দেখা যায় এবং ক্লাউডে সিঙ্ক হয়।"
        },
        {
          icon: "🛡️",
          title: "টিম, কার্যকলাপ ও অডিট লগ",
          steps: [
            { label: "আপনার অর্গ বিবরণ পেজ খুলুন।", desc: "ড্যাশবোর্ডে যেকোনো অর্গ কার্ডে ট্যাপ করে সম্পূর্ণ সারাংশ দেখুন।" },
            { label: "Team Members দেখুন।", desc: "Team টাইল সব স্টাফকে রোল-রঙিন অবতারসহ দেখায়, নাম/ইমেল অনুসন্ধান ও রোল ফিল্টারসহ।" },
            { label: "Recent Activity পরীক্ষা করুন।", desc: "Activity টাইল কার্যকলাপের (auth, loan, payment, savings, member) লগ দেখায় — কে কী এবং কখন করেছে।" },
            { label: "Security & Activity Logs খুলুন।", desc: "Settings → Security & Compliance-এ System Activity Logs খুলুন এবং অডিট রিটেনশন, পাসওয়ার্ড নীতি, এবং Google Drive ব্যাকআপ সেট করুন।" }
          ],
          note: "অডিট লগ প্রতিটি পরিবর্তন খুঁজে বের করতে সাহায্য করে — পর্যালোচনা বা বিরোধের সময় উপযোগী।"
        }
      ]
    },
    branchManager: {
      title: "শাখা ব্যবস্থাপক গাইড (Branch Manager)",
      desc: "শাখা ব্যবস্থাপক হিসেবে আপনি আপনার শাখার প্রধান। নতুন গ্রাহক নথিভুক্ত করা, ফিল্ড এজেন্টের তদারকি করা, লোনের আবেদন যাচাই করে অনুমোদন করা এবং ব্রাঞ্চের কালেকশন মেলাবেন কীভাবে তা জানুন।",
      lessons: [
        {
          icon: "🚀",
          title: "শুরু করা — ম্যানেজার লগইন",
          steps: [
            { label: "মূল অ্যাডমিন প্রেরিত ইনভাইট ইমেলটি ওপেন করুন।" },
            { label: "পাসওয়ার্ড সেট করুন এবং আপনার অ্যাকাউন্টে সাইন ইন করুন।" },
            { label: "ব্রাঞ্চ ড্যাশবোর্ড দেখুন - এখানে প্রতিদিনের কালেকশন ও কালেকশন লক্ষ্যমাত্রা দেখতে পাবেন।" }
          ]
        },
        {
          icon: "👥",
          title: "নতুন মেম্বার যুক্ত করা (Member Onboarding)",
          steps: [
            { label: "Members > Onboard Member অপশনে যান।", desc: "গ্রাহকের পরিচয়পত্র (আধার বা ভোটার কার্ড) সঙ্গে রাখুন।" },
            { label: "গ্রাহকের নাম, ঠিকানা, মোবাইল নম্বর এবং পরিচয়পত্রের নম্বর লিখুন।", desc: " পরিচয়পত্রের ছবি আপলোড করুন।" },
            { label: "সাবমিট করুন। মেম্বার প্রোফাইল তৈরি হয়ে এবং তাঁর মেম্বার আইডি তৈরি হয়ে যাবে।" }
          ],
          note: "লোন মঞ্জুর করার আগে মেম্বারের কেওয়াইসি (KYC) যাচাই করা আবশ্যক।"
        },
        {
          icon: "💰",
          title: "লোনের আবেদন অনুমোদন (Approve Loan)",
          steps: [
            { label: "Loans > Pending Approvals অপশনে যান।", desc: "গ্রাহকের পুরো লোনের ফাইল ও তথ্যাদি খতিয়ে দেখুন।" },
            { label: "মেম্বারের ঋণ যোগ্যতা এবং বিগত সঞ্চয়ের পরিমাণ যাচাই করুন।" },
            { label: "সব ঠিক থাকলে 'Approve' ক্লিক করুন লোন ডিস্ট্রিবিউট করার জন্য।" }
          ],
          note: "লোন পাস হওয়ার সাথে সাথে কিস্তি জমার তারিখের তালিকা (EMI Schedule) তৈরি হয়ে যাবে।"
        },
        {
          icon: "📍",
          title: "ফিল্ড স্টাফ লাইভ ট্র্যাকিং",
          steps: [
            { label: "মেনু প্যানেল থেকে 'Live Map' অপশনটি খুলুন।", desc: "এটি ম্যাপের মাধ্যমে ট্র্যাকিং উইন্ডো নিয়ে আসবে।" },
            { label: "আপনার ব্রাঞ্চের ফিল্ড এজেন্টদের অবস্থান ম্যাপে দেখুন।", desc: "সবুজ মানে ডিউটি করছেন এবং ধূসর বা গ্রে মানে অফ-ডিউটি।" },
            { label: "এজেন্টের নামের ওপর ক্লিক করে দেখুন আজ তিনি কটি কিস্তি এবং কত কালেকশন করেছেন।" }
          ],
          note: "লোকেশন দেখতে হলে এজেন্টের মোবাইলের জিপিএস এবং অ্যাপে 'Duty ON' বাটন অন থাকতে হবে।"
        }
      ]
    },
    collectionAgent: {
      title: "কালেকশন এজেন্ট গাইড (Field Agent)",
      desc: "ফিল্ড বা মাঠ পর্যায়ের কিস্তি সংগ্রহকারী এজেন্টদের জন্য গাইড। কীভাবে আপনার কালেকশন রুট ম্যাপে দেখবেন, কিস্তি তুলবেন, ইন্টারনেট ছাড়াই কালেকশন ডেটা সিঙ্ক করবেন তা জানুন।",
      lessons: [
        {
          icon: "🚀",
          title: "মোবাইল অ্যাপ ব্যবহার ও লগইন",
          steps: [
            { label: "ম্যানেজারের পাঠানো লিঙ্ক থেকে MicroFlow Pro অ্যাপটি ডাউনলোড করুন।", desc: "জিপিএস এবং এসএমএস পারমিশন চালু করুন।" },
            { label: "আপনার রেজিস্টার্ড ইমেল এবং পাসওয়ার্ড দিয়ে লগইন করুন।" },
            { label: "ড্যাশবোর্ডে গিয়ে আজকের কালেকশনের তালিকা দেখে নিন।" }
          ]
        },
        {
          icon: "🔘",
          title: "ডিউটি অন বা অফ করা (Duty ON/OFF)",
          steps: [
            { label: "ড্যাশবোর্ডের একদম ওপরে 'Duty Toggle' অপশনটি দেখুন।" },
            { label: "মাঠে কিস্তি তুলতে বেরোনোর আগে অবশ্যই 'Duty ON' করে নেবেন।" },
            { label: "দিনের কাজ শেষ হওয়ার পর 'Duty OFF' করুণ যাতে লোকেশন ট্র্যাকিং বন্ধ হয় এবং মোবাইলের ব্যাটারি বাঁচে।" }
          ],
          note: "ডিউটি অন না করা থাকলে আপনার লোকেশন ম্যানেজার ম্যাপে দেখতে পাবেন না।"
        },
        {
          icon: "💰",
          title: "দৈনিক কিস্তি (EMI) সংগ্রহ করা",
          steps: [
            { label: "'Today's Collection' ট্যাবে যান।", desc: "আজকে রুট ভিত্তিক গ্রাহকদের তালিকা এখানে দেখতে পাবেন।" },
            { label: "গ্রাহকের নামের ওপর ট্যাপ করে লোনের তথ্য দেখে নিন।" },
            { label: " সংগৃহীত কিস্তির টাকা ও কালেকশন মোড বাছুন (Cash বা UPI) এবং 'Collect' চাপুন।", desc: "জমা হওয়ার তাৎক্ষণিক কনফার্মেশন এসএমএস গ্রাহকের মোবাইলে চলে যাবে।" }
          ]
        },
        {
          icon: "⚡",
          title: "ইন্টারনেট ছাড়া কালেকশন (Offline Sync)",
          steps: [
            { label: "নেটওয়ার্ক না থাকলেও কিস্তি আদায় জারি রাখুন।" },
            { label: "ড্যাশবোর্ডের নিচে 'Offline Queue' ব্যাজটি দেখুন।", desc: "এটি সিঙ্ক না হওয়া কালেকশনের সংখ্যা দেখায়।" },
            { label: "ফোনে ইন্টারনেট আসা মাত্রই সিঙ্ক ব্যাজটিতে ক্লিক করুন। সমস্ত ডাটা ক্লাউডে সুরক্ষিতভাবে চলে যাবে।" }
          ],
          note: "যতক্ষণ না আপনার অফলাইন কালেকশন সম্পূর্ণ সিঙ্ক (Sync) হচ্ছে, অ্যাপ থেকে লগ আউট করবেন না।"
        }
      ]
    },
    customer: {
      title: "গ্রাহক নির্দেশিকা (Customer App)",
      desc: "গ্রাহকদের জন্য সহজ নির্দেশিকা। নিজের মোবাইলের মাধ্যমে কত টাকা লোন নেওয়া হয়েছে, কত জমা পড়েছে, কত বাকি আছে এবং লোনের পিডিএফ স্টেটমেন্ট ডাউনলোড করার সহজ তথ্য।",
      lessons: [
        {
          icon: "📱",
          title: "ওটিপি (OTP) দিয়ে সহজ লগইন",
          steps: [
            { label: "আপনার মোবাইলে 'MicroFlow Pro' কাস্টমার অ্যাপটি খুলুন।" },
            { label: "আপনার রেজিস্টার্ড মোবাইল নম্বরটি লিখে জমা দিন।" },
            { label: "মোবাইলে আসা ৬ অক্ষরের ওটিপি নম্বরটি লিখুন এবং ভেরিফাই করুন।" }
          ]
        },
        {
          icon: "📋",
          title: "লোন স্টেটমেন্ট ডাউনলোড",
          steps: [
            { label: "অ্যাপের 'My Loans' (আমার লোন) অপশনে যান।" },
            { label: "আপনার চলতি লোন অ্যাকাউন্টটি ক্লিক করুন।" },
            { label: "'Download Statement'-এ ক্লিক করুন।", desc: "স্টেটমেন্ট পিডিএফ আপনার মোবাইলের মেমরিতে ডাউনলোড হবে।" }
          ],
          note: "স্টেটমেন্ট পিডিএফ ফাইলে জমার তারিখ, সুদের হার, মোট বকেয়া ও কত কিস্তি দিলেন সব কিছু বিস্তারিত থাকে।"
        },
        {
          icon: "💰",
          title: "সঞ্চয় হিসাবের ব্যালেন্স দেখা",
          steps: [
            { label: "ড্যাশবোর্ড থেকে 'My Savings' (আমার ডিপিএস/সঞ্চয়) অপশনে যান।" },
            { label: "মোট কত টাকা সঞ্চয় জমা পড়েছে এবং ও সুদের হার দেখে নিন।" },
            { label: "এজেন্টকে দেওয়া টাকা এবং অ্যাপের রিফ্লেকশন মিলিয়ে নিন।" }
          ]
        }
      ]
    }
  }
};
