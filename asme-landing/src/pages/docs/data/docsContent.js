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
  en: {
    common: {
      allGuides: "All Guides", backToHome: "Home", documentation: "Documentation",
      quickLinks: "Quick Links", portalGuides: "Guides", watchVideo: "Watch Video",
      openGuide: "Open Guide", stepsTitle: "Step-by-Step Guide", lessons: "lessons",
      portals: "guides", youtube: "YouTube", selectPortal: "Select a Guide",
      openGuideAction: "Open guide", subscribe: "Subscribe", popularGuides: "Popular Guides",
      youtubeCtaTitle: "Video Tutorials Available",
      youtubeCtaDesc: "Detailed video tutorials for every topic. Explained in simple, easy-to-follow steps. Subscribe to our YouTube channel to get updates on new videos.",
    },
    home: {
      title: "Documentation",
      subtitle: "Step-by-step guides with video tutorials",
      desc: "MicroFlow Pro — the simple book-keeping tool for individual money-lenders. Track loans, collect repayments, and stay on top of your interest earnings. These guides walk you through every feature.",
      portals: {
        admin: { title: "Getting Started", desc: "Sign up, set up your profile, and add your first borrower." },
        manager: { title: "Managing Borrowers", desc: "Add and edit borrower details, contact info, and loan history." },
        agent: { title: "Recording Loans", desc: "Create loans, set interest rates, terms, and amounts for your borrowers." },
        customer: { title: "Tracking Repayments", desc: "Log repayments, view outstanding balances, and track your interest earnings." },
      },
      topics: [
        { label: "📱 App Download & Login", path: "/docs/getting-started" },
        { label: "👤 Add Your First Borrower", path: "/docs/managing-borrowers" },
        { label: "💰 Create Your First Loan", path: "/docs/recording-loans" },
        { label: "📊 Record a Repayment", path: "/docs/tracking-repayments" },
        { label: "📨 Set Up SMS Reminders", path: "/docs/sms-reminders" },
        { label: "📈 Understand Your Portfolio", path: "/docs/portfolio-insights" },
      ]
    },
    gettingStarted: {
      title: "Getting Started",
      desc: "New to MicroFlow Pro? This guide covers everything you need to set up your account, create your lender profile, and add your first borrower. It takes about 5 minutes.",
      lessons: [
        {
          icon: "📲", title: "Download & Install the App",
          steps: [
            { label: "Open your phone's app store.", desc: "Search for 'MicroFlow Pro' on Google Play Store (Android) or App Store (iOS)." },
            { label: "Tap 'Install' and wait for the download to complete.", desc: "The app is about 45 MB." },
            { label: "Open the app once installed.", desc: "You'll see the welcome screen with Sign In and Create Account options." },
          ]
        },
        {
          icon: "✍️", title: "Create Your Account",
          steps: [
            { label: "Tap 'Create Account' on the welcome screen.", desc: "A simple form opens with fields for your name, phone number, email, and password." },
            { label: "Fill in your details.", desc: "Enter your full name, a 10-digit mobile number, a valid email address, and a password (minimum 8 characters). Confirm your password." },
            { label: "Accept the terms.", desc: "Check the box to agree to the Terms of Service and Privacy Policy." },
            { label: "Tap 'Create Account'.", desc: "You'll receive a verification email. Tap the link to verify, then return to the app and sign in." },
          ],
          note: "Your account is ready immediately after email verification. No organization setup or trial period — start lending right away."
        },
        {
          icon: "👤", title: "Set Up Your Profile",
          steps: [
            { label: "Go to Settings after signing in.", desc: "Tap the menu icon (top right) and select Settings." },
            { label: "Fill in your personal details.", desc: "Add your full name, phone number, email, and a profile photo if you'd like." },
            { label: "Set your preferences.", desc: "Choose your preferred language, enable dark mode, and turn on biometric login for faster access." },
          ],
          note: "You can update these details anytime from Settings. Your profile is private — only you can see it."
        },
        {
          icon: "🧑", title: "Add Your First Borrower",
          steps: [
            { label: "From the home screen, tap the 'Borrowers' tab.", desc: "This shows your borrower list. When new, it will be empty." },
            { label: "Tap the '+' button (top right).", desc: "The 'Add Borrower' form opens." },
            { label: "Enter the borrower's details.", desc: "Full name, mobile number, address, and an optional note." },
            { label: "Tap 'Save Borrower'.", desc: "The borrower is added. You can now create a loan for them." },
          ],
          note: "No plan limits — add as many borrowers as you need. Make sure the mobile number is correct — it's used for SMS repayment reminders."
        },
        {
          icon: "🔔", title: "Enable SMS Reminders (Optional)",
          steps: [
            { label: "Go to Settings → SMS Settings.", desc: "Scroll down to the Communications section." },
            { label: "Turn on 'Due EMI Reminders'.", desc: "This sends automatic SMS reminders to borrowers before their EMI is due." },
            { label: "Set a reminder time.", desc: "Pick a time of day when reminders should be sent — e.g., 9:00 AM every morning." },
          ],
          note: "SMS is sent from your phone's SIM card. No external SMS service or extra cost required. Make sure your SIM has sufficient balance."
        },
      ]
    },
    managingBorrowers: {
      title: "Managing Borrowers",
      desc: "Your borrowers are the people you lend money to. This guide shows you how to add, edit, and manage borrower profiles — including contact details, loan history, and repayment records.",
      lessons: [
        {
          icon: "➕", title: "Add a New Borrower",
          steps: [
            { label: "Go to the Borrowers tab.", desc: "From the home screen, tap 'Borrowers'." },
            { label: "Tap the '+' button.", desc: "The Add Borrower form opens." },
            { label: "Enter the borrower's full name.", desc: "This name appears on all loan documents and receipts." },
            { label: "Enter their mobile number.", desc: "Required — used for SMS reminders and receipts." },
            { label: "Enter their address (optional).", desc: "Useful for your records and field visits." },
            { label: "Add a note (optional).", desc: "Note how you know them, their occupation, or other details." },
            { label: "Tap 'Save'.", desc: "The borrower is added to your list." },
          ],
          note: "A borrower's mobile number is the only field required for SMS reminders. Make sure it's accurate."
        },
        {
          icon: "✏️", title: "Edit Borrower Details",
          steps: [
            { label: "Go to the Borrowers tab.", desc: "Find the borrower you want to edit." },
            { label: "Tap on the borrower's name.", desc: "This opens their profile page." },
            { label: "Tap the 'Edit' button (top right).", desc: "Change name, mobile number, address, and notes." },
            { label: "Tap 'Save' when done.", desc: "Changes are saved immediately." },
          ],
          note: "Changing a borrower's mobile number also updates it for all their active loans and SMS reminders."
        },
        {
          icon: "📋", title: "View Borrower's Loan History",
          steps: [
            { label: "Go to the Borrowers tab.", desc: "Find and tap on the borrower." },
            { label: "Scroll down to see their loan history.", desc: "All loans (active, completed, defaulted) are listed with current status." },
            { label: "Tap on any loan for full details.", desc: "See the EMI schedule, payments made, outstanding balance, and interest earned." },
          ],
          note: "Check loan history before giving a new loan — it shows how reliable the borrower is."
        },
        {
          icon: "🗑️", title: "Remove a Borrower",
          steps: [
            { label: "Go to the borrower's profile page.", desc: "Find the borrower and tap their name." },
            { label: "Tap the 'More' menu (three dots, top right).", desc: "Select 'Remove Borrower'." },
            { label: "Confirm the removal.", desc: "Tap 'Remove' in the confirmation dialog." },
          ],
          note: "Removing a borrower does not delete their loan history — all loan records are preserved."
        },
      ]
    },
    recordingLoans: {
      title: "Recording Loans",
      desc: "Creating a loan is the core of MicroFlow Pro. This guide covers how to set up a new loan, configure interest rates and terms, and start tracking repayments.",
      lessons: [
        {
          icon: "💰", title: "Create a New Loan",
          steps: [
            { label: "From the home screen, tap 'Loans'.", desc: "This shows all your loans — active, pending, and completed." },
            { label: "Tap the '+' button.", desc: "The 'New Loan' form opens." },
            { label: "Select the borrower.", desc: "Choose from your borrower list. If not there yet, tap 'Add New Borrower' first." },
            { label: "Enter the loan amount.", desc: "Type the principal amount (e.g., ₹10,000)." },
            { label: "Set the interest rate.", desc: "Enter the annual interest rate as a percentage (e.g., 12% per year)." },
            { label: "Choose the interest type.", desc: "Flat: same interest every month. Reducing: interest on remaining balance (lower total interest)." },
            { label: "Set the loan term.", desc: "Choose how many months the loan will run (e.g., 12 months)." },
            { label: "Pick the collection frequency.", desc: "Daily, weekly, or monthly — how often the borrower repays." },
            { label: "Set the first EMI date.", desc: "Pick when the first repayment is due." },
            { label: "Review and tap 'Create Loan'.", desc: "The EMI schedule is generated automatically — you'll see each installment amount and due date." },
          ],
          note: "The EMI schedule shows every installment with its due date and amount. View it anytime from the loan detail page."
        },
        {
          icon: "🧮", title: "Understanding Interest Calculation",
          steps: [
            { label: "Open any active loan.", desc: "Go to Loans → tap on the loan." },
            { label: "Look at the EMI schedule.", desc: "Each row shows installment number, due date, EMI amount, principal, interest, and remaining balance." },
            { label: "Compare flat vs reducing.", desc: "Flat: same total interest every month. Reducing: interest decreases over time as principal is paid down." },
            { label: "Check the total interest.", desc: "At the bottom of the schedule, see the total interest earned over the loan term." },
          ],
          note: "Reducing balance is usually better for borrowers (lower total interest) and shows you how much interest you've earned at any point."
        },
        {
          icon: "✏️", title: "Edit an Active Loan",
          steps: [
            { label: "Open the loan you want to edit.", desc: "Go to Loans → tap on the loan." },
            { label: "Tap the 'Edit' button.", desc: "Change the interest rate, term, or collection frequency." },
            { label: "Tap 'Save'.", desc: "The EMI schedule is recalculated automatically." },
          ],
          note: "Be careful when changing interest rate or term — it recalculates all future EMIs. Past payments are not affected."
        },
        {
          icon: "⏸️", title: "Pause or Close a Loan",
          steps: [
            { label: "Open the loan you want to manage.", desc: "Go to Loans → tap on the loan." },
            { label: "Tap the 'More' menu (three dots).", desc: "You'll see options to Pause, Resume, or Close the loan." },
            { label: "Choose 'Close Loan' when fully repaid.", desc: "This marks the loan as completed and moves it to your loan history." },
          ],
          note: "Closing a loan is permanent. Make sure all outstanding EMIs are settled before closing."
        },
      ]
    },
    trackingRepayments: {
      title: "Tracking Repayments",
      desc: "Recording repayments keeps your books accurate. This guide shows you how to log payments, view outstanding balances, and track your interest earnings.",
      lessons: [
        {
          icon: "💵", title: "Record a Repayment",
          steps: [
            { label: "Go to the Loans tab.", desc: "Find the active loan you want to record a payment for." },
            { label: "Tap on the loan.", desc: "This opens the loan detail page with the EMI schedule." },
            { label: "Tap 'Record Payment'.", desc: "A form opens to enter payment details." },
            { label: "Enter the payment amount.", desc: "You can enter the full EMI amount or a partial payment." },
            { label: "Select the payment mode.", desc: "Cash, UPI, or Bank Transfer." },
            { label: "Add a note (optional).", desc: "E.g., 'Paid late by 2 days' or 'Part payment'." },
            { label: "Tap 'Save'.", desc: "The payment is recorded and the outstanding balance updates automatically." },
          ],
          note: "An SMS receipt is sent to the borrower automatically if SMS is enabled. The EMI schedule updates to reflect the payment."
        },
        {
          icon: "📊", title: "Check Outstanding Balance",
          steps: [
            { label: "Go to the Loans tab.", desc: "All active loans are listed here." },
            { label: "Look at the 'Outstanding' column.", desc: "This shows how much the borrower still owes you." },
            { label: "Tap on any loan for full details.", desc: "See the full amortization schedule, payments made, and remaining balance." },
          ],
          note: "The outstanding balance updates automatically after every repayment. No manual calculations needed."
        },
        {
          icon: "📈", title: "Track Interest Earned",
          steps: [
            { label: "Open any active loan.", desc: "Go to Loans → tap on the loan." },
            { label: "Check the EMI schedule.", desc: "Each installment shows the interest portion — your earnings for that period." },
            { label: "View total interest earned.", desc: "At the bottom of the schedule, see total interest collected so far and projected total." },
          ],
          note: "Interest is calculated automatically based on your chosen rate and type (flat or reducing). No manual calculation needed."
        },
        {
          icon: "⏰", title: "Handle Late or Missed Payments",
          steps: [
            { label: "Check the EMI schedule for overdue installments.", desc: "Overdue EMIs are highlighted in red." },
            { label: "Contact the borrower.", desc: "Use the borrower's mobile number to follow up." },
            { label: "Record the payment when received.", desc: "Even if late, record it as normal — the app tracks the delay." },
            { label: "Consider restructuring if needed.", desc: "For borrowers who consistently miss payments, extend the term or reduce the EMI." },
          ],
          note: "Late payments don't automatically incur penalties in the app. If you charge a late fee, record it as a separate transaction."
        },
      ]
    },
    smsReminders: {
      title: "SMS Reminders",
      desc: "Set up automatic SMS reminders to nudge borrowers before EMI due dates. Reduce manual follow-up and improve repayment rates.",
      lessons: [
        {
          icon: "⚙️", title: "Set Up SMS Reminders",
          steps: [
            { label: "Go to Settings → SMS Settings.", desc: "Scroll to the Communications section." },
            { label: "Turn on 'Due EMI Reminders'.", desc: "Enables automatic reminders for all active loans." },
            { label: "Set the reminder time.", desc: "Choose when reminders should be sent — e.g., 9:00 AM." },
            { label: "Choose how many days before due.", desc: "Send reminders 1, 2, or 3 days before the EMI is due." },
            { label: "Tap 'Save Settings'.", desc: "Reminders will now be sent automatically." },
          ],
          note: "SMS is sent from your phone's SIM card. Make sure your SIM has sufficient balance. No external SMS service — completely free."
        },
        {
          icon: "📝", title: "Customize Reminder Messages",
          steps: [
            { label: "Go to Settings → SMS Settings.", desc: "Scroll to the Reminder Templates section." },
            { label: "Edit the reminder message.", desc: "Customize the text. Use placeholders like {name}, {amount}, {due_date}, and {loan_id}." },
            { label: "Preview the message.", desc: "See how the message will look when sent to a borrower." },
            { label: "Tap 'Save Template'.", desc: "Your custom message will be used for all future reminders." },
          ],
          note: "Keep messages short and friendly. Default: 'Namaste {name}, your EMI of ₹{amount} is due on {due_date}. Please pay to avoid late fees.'"
        },
        {
          icon: "📱", title: "Send a Manual Reminder",
          steps: [
            { label: "Go to the Borrowers tab.", desc: "Find the borrower you want to remind." },
            { label: "Tap on the borrower's name.", desc: "This opens their profile page." },
            { label: "Tap 'Send Reminder'.", desc: "An SMS is sent immediately with the default or custom message." },
          ],
          note: "Use manual reminders for one-off follow-ups, like when a borrower has missed a payment."
        },
        {
          icon: "🔕", title: "Opt-Out for Specific Borrowers",
          steps: [
            { label: "Open the borrower's profile.", desc: "Go to Borrowers → tap on the borrower." },
            { label: "Tap 'SMS Settings'.", desc: "You'll see a toggle for SMS reminders." },
            { label: "Turn off SMS for this borrower.", desc: "They won't receive automated reminders, but you can still send manual ones." },
          ],
          note: "Respect your borrowers' preferences. If someone asks not to receive reminders, toggle SMS off for them."
        },
      ]
    },
    portfolioInsights: {
      title: "Understanding Your Portfolio",
      desc: "Your portfolio is the complete picture of all your lending activity. This guide helps you understand total lent, outstanding, interest earned, and repayment rate.",
      lessons: [
        {
          icon: "🏦", title: "View Your Portfolio Summary",
          steps: [
            { label: "Go to the Portfolio tab from the home screen.", desc: "This gives you a complete overview of your lending business." },
            { label: "Check the key numbers.", desc: "Total Lent, Outstanding Amount, Total Interest Earned, and Active Loans are shown at the top." },
            { label: "Scroll down for more details.", desc: "You'll see repayment rates, borrower breakdown, and monthly trends." },
          ],
          note: "These numbers update in real-time as you record repayments. No manual calculation needed."
        },
        {
          icon: "📊", title: "Understanding the Numbers",
          steps: [
            { label: "Total Lent.", desc: "Sum of all loan amounts you've ever given out — active, completed, and defaulted loans." },
            { label: "Outstanding Amount.", desc: "How much is currently owed to you across all active loans. Goes down as borrowers repay." },
            { label: "Interest Earned.", desc: "Total interest collected so far. This is your earnings from lending." },
            { label: "Repayment Rate.", desc: "Percentage of EMIs paid on time. A high rate means reliable borrowers." },
          ],
          note: "Track your repayment rate monthly — it's the best indicator of your lending portfolio's health."
        },
        {
          icon: "📈", title: "Monthly Trends & Reports",
          steps: [
            { label: "Go to the Portfolio tab.", desc: "Scroll to the Trends section." },
            { label: "View the monthly chart.", desc: "See how your lending, repayments, and interest earnings have changed over time." },
            { label: "Filter by date range.", desc: "Choose a specific month or quarter for detailed numbers." },
          ],
          note: "Use monthly trends to plan your lending — see which months have high repayment rates and which borrowers are most reliable."
        },
        {
          icon: "🎯", title: "Improve Your Repayment Rate",
          steps: [
            { label: "Identify slow payers.", desc: "Check the Portfolio tab for borrowers with overdue EMIs." },
            { label: "Follow up early.", desc: "Use SMS reminders to nudge borrowers before their due date." },
            { label: "Review loan terms.", desc: "If borrowers struggle, consider reducing the EMI or extending the loan term." },
            { label: "Build relationships.", desc: "Best repayment rates come from knowing your borrowers well — keep contact details updated and check in regularly." },
          ],
          note: "A good repayment rate (above 85%) means your lending business is healthy. Below 70% may indicate issues with borrower selection or loan terms."
        },
      ]
    },
  },

  hi: {
    common: {
      allGuides: "सभी मार्गदर्शिकाएँ", backToHome: "होम", documentation: "दस्तावेज़ (Docs)",
      quickLinks: "त्वरित लिंक्स", portalGuides: "मार्गदर्शिकाएँ", watchVideo: "वीडियो देखें",
      openGuide: "गाइड खोलें", stepsTitle: "चरण-दर-चरण मार्गदर्शिका", lessons: "पाठ",
      portals: "गाइड", youtube: "यूट्यूब", selectPortal: "एक मार्गदर्शिका चुनें",
      openGuideAction: "गाइड खोलें", subscribe: "सब्सक्राइब", popularGuides: "लोकप्रिय गाइड्स",
      youtubeCtaTitle: "वीडियो ट्यूटोरियल उपलब्ध हैं",
      youtubeCtaDesc: "हर विषय के लिए विस्तृत वीडियो ट्यूटोरियल। सरल, आसान चरणों में समझाया गया है। नए वीडियो की जानकारी पाने के लिए हमारे यूट्यूब चैनल को सब्सक्राइब करें।",
    },
    home: {
      title: "दस्तावेज़", subtitle: "वीडियो ट्यूटोरियल के साथ चरण-दर-चरण गाइड",
      desc: "माइक्रोफ्लो प्रो — व्यक्तिगत पैसे उधार देने वालों के लिए सरल बही-खाता टूल। ऋण देना, किस्तें लेना, और ब्याज कमाना ट्रैक करें। ये गाइड हर फीचर को कवर करते हैं।",
      portals: {
        admin: { title: "शुरुआत करें", desc: "अकाउंट बनाएं, प्रोफाइल सेट करें, और अपना पहला उधारी जोड़ें।" },
        manager: { title: "उधारियों का प्रबंधन", desc: "उधारियों की जानकारी जोड़ें, संपर्क विवरण, और ऋण इतिहास देखें।" },
        agent: { title: "ऋण दर्ज करना", desc: "उधारियों के लिए ऋण बनाएं, ब्याज दर, अवधि और राशि सेट करें।" },
        customer: { title: "किस्तें ट्रैक करना", desc: "भुगतान दर्ज करें, बकाया देखें, और अपने ब्याज कमाई का हिसाब रखें।" },
      },
      topics: [
        { label: "📱 ऐप डाउनलोड और लॉगिन", path: "/docs/getting-started" },
        { label: "👤 अपना पहला उधारी जोड़ें", path: "/docs/managing-borrowers" },
        { label: "💰 अपना पहला ऋण बनाएं", path: "/docs/recording-loans" },
        { label: "📊 किस्त भुगतान दर्ज करें", path: "/docs/tracking-repayments" },
        { label: "📨 एसएमएस रिमाइंडर सेट करें", path: "/docs/sms-reminders" },
        { label: "📈 अपने पोर्टफोलियो को समझें", path: "/docs/portfolio-insights" },
      ]
    },
    gettingStarted: {
      title: "शुरुआत करें",
      desc: "माइक्रोफ्लो प्रो में नया हैं? यह गाइड आपके अकाउंट सेटअप, लेंडर प्रोफाइल बनाने और पहले उधारी को जोड़ने के बारे में हर चीज बताती है। इसमें लगभग 5 मिनट लगेंगे।",
      lessons: [
        {
          icon: "📲", title: "ऐप डाउनलोड करें",
          steps: [
            { label: "अपने फोन के ऐप स्टोर खोलें।", desc: "Google Play Store (Android) या App Store (iOS) पर 'MicroFlow Pro' सर्च करें।" },
            { label: "'Install' पर टैप करें और डाउनलोड होने का इंतज़ार करें।", desc: "ऐप लगभग 45 MB का है।" },
            { label: "डाउनलोड होने पर ऐप खोलें।", desc: "आपको वेलकम स्क्रीन दिखेगी जिसमें 'Sign In' और 'Create Account' दो विकल्प होंगे।" },
          ]
        },
        {
          icon: "✍️", title: "अकाउंट बनाएं",
          steps: [
            { label: "वेलकम स्क्रीन पर 'Create Account' पर टैप करें।", desc: "एक सरल फॉर्म खुलेगा जिसमें आपका नाम, फोन नंबर, ईमेल और पासवर्ड मांगा जाएगा।" },
            { label: "अपना विवरण भरें।", desc: "पूरा नाम, 10 अंकों का मोबाइल नंबर, वैध ईमेल पता, और पासवर्ड (कम से कम 8 अक्षर) डालें। पासवर्ड को कन्फर्म करें।" },
            { label: "नियम स्वीकार करें।", desc: "Terms of Service और Privacy Policy स्वीकार करने के लिए चेकबॉक्स पर टैप करें।" },
            { label: "'Create Account' दबाएं।", desc: "आपको एक वेरिफिकेशन ईमेल मिलेगा। लिंक पर क्लिक करें, फिर ऐप में साइन इन करें।" },
          ],
          note: "ईमेल वेरीफाई होने के बाद आपका अकाउंट तुरंत तैयार हो जाता है। कोई संगठन सेटअप या ट्रायल अवधि नहीं — आप सीधे उधार देना शुरू कर सकते हैं।"
        },
        {
          icon: "👤", title: "अपना प्रोफाइल सेट करें",
          steps: [
            { label: "साइन इन करने के बाद Settings पर जाएं।", desc: "मेनू आइकन (ऊपर दाईं ओर) पर टैप करें और Settings चुनें।" },
            { label: "अपना विवरण भरें।", desc: "पूरा नाम, फोन नंबर, ईमेल और यदि चाहें तो प्रोफाइल फोटो जोड़ें।" },
            { label: "अपनी पसंद सेट करें।", desc: "पसंदीदा भाषा चुनें, डार्क मोड चालू करें, और बायोमेट्रिक लॉगिन सक्षम करें।" },
          ],
          note: "आप Settings से कभी भी अपडेट कर सकते हैं। आपका प्रोफाइल निजी है — केवल आप ही इसे देख सकते हैं।"
        },
        {
          icon: "🧑", title: "अपना पहला उधारी जोड़ें",
          steps: [
            { label: "होम स्क्रीन से 'Borrowers' टैब पर जाएं।", desc: "यह आपके सभी उधारियों की सूची दिखाता है। नए होने पर यह खाली होगा।" },
            { label: "ऊपर दाईं ओर '+' बटन पर टैप करें।", desc: "'Add Borrower' फॉर्म खुलेगा।" },
            { label: "उधारी का विवरण डालें।", desc: "पूरा नाम, मोबाइल नंबर, पता, और एक वैकल्पिक नोट।" },
            { label: "'Save Borrower' पर टैप करें।", desc: "उधारी आपकी सूची में जुड़ जाता है। अब आप उसके लिए ऋण बना सकते हैं।" },
          ],
          note: "आप जितने चाहें उतने उधारी जोड़ सकते हैं — कोई प्लान सीमा नहीं। मोबाइल नंबर सही हो — इससे एसएमएस रिमाइंडर भेजे जाते हैं।"
        },
        {
          icon: "🔔", title: "एसएमएस रिमाइंडर चालू करें (वैकल्पिक)",
          steps: [
            { label: "Settings → SMS Settings पर जाएं।", desc: "Communications सेक्शन तक स्क्रॉल करें।" },
            { label: "'Due EMI Reminders' चालू करें।", desc: "यह उधारियों को EMI देय होने से पहले स्वचालित रिमाइंडर भेजता है।" },
            { label: "रिमाइंडर का समय सेट करें।", desc: "उस समय चुनें जब रिमाइंडर भेजना है — उदाहरण: सुबह 9:00 बजे।" },
          ],
          note: "एसएमएस आपके फोन की SIM कार्ड से भेजा जाता है। कोई बाहरी SMS सर्विस या अतिरिक्त लागत नहीं। अपनी SIM में पर्याप्त बैलेंस रखें।"
        },
      ]
    },
    managingBorrowers: {
      title: "उधारियों का प्रबंधन",
      desc: "उधारी वे लोग हैं जिनसे आप पैसा उधार देते हैं। यह गाइड आपको बताती है कि उधारी प्रोफाइल कैसे जोड़ें, संपादित करें और प्रबंधित करें — संपर्क विवरण, ऋण इतिहास और भुगतान रिकॉर्ड सहित।",
      lessons: [
        {
          icon: "➕", title: "नया उधारी जोड़ें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "होम स्क्रीन से नीचे 'Borrowers' पर टैप करें।" },
            { label: "'+' बटन पर टैप करें।", desc: "'Add Borrower' फॉर्म खुलेगा।" },
            { label: "उधारी का पूरा नाम डालें।", desc: "यह नाम सभी ऋण दस्तावेजों और रसीदों पर दिखेगा।" },
            { label: "मोबाइल नंबर डालें।", desc: "यह आवश्यक है — एसएमएस रिमाइंडर और रसीदों के लिए उपयोग होता है।" },
            { label: "पता डालें (वैकल्पिक)।", desc: "अपने रिकॉर्ड के लिए उपयोगी।" },
            { label: "नोट जोड़ें (वैकल्पिक)।", desc: "उदाहरण: रिश्ता, पेशा, या कोई अन्य विवरण।" },
            { label: "'Save' पर टैप करें।", desc: "उधारी आपकी सूची में जुड़ जाता है।" },
          ],
          note: "एसएमएस रिमाइंडर भेजने के लिए केवल उधारी का मोबाइल नंबर आवश्यक है। सही नंबर डालें।"
        },
        {
          icon: "✏️", title: "उधारी के विवरण को संपादित करें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "जिस उधारी को संपादित करना है, उसे ढूंढें।" },
            { label: "उधारी के नाम पर टैप करें।", desc: "यह उनकी प्रोफाइल पेज खोलेगा।" },
            { label: "'Edit' बटन पर टैप करें।", desc: "अब आप नाम, मोबाइल नंबर, पता और नोट बदल सकते हैं।" },
            { label: "'Save' पर टैप करें।", desc: "बदलाव तुरंत सेव हो जाते हैं।" },
          ],
          note: "उधारी के मोबाइल नंबर बदलने से उनके सभी एक्टिव लोन और एसएमएस रिमाइंडर भी अपडेट हो जाएंगे।"
        },
        {
          icon: "📋", title: "उधारी के ऋण इतिहास देखें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "जिस उधारी की जांच करना है, उसे ढूंढें और नाम पर टैप करें।" },
            { label: "नीचे स्क्रॉल करके उनके ऋण इतिहास देखें।", desc: "सभी लोन (एक्टिव, पूरे हुए, डिफॉल्टेड) यहां सूचीबद्ध हैं।" },
            { label: "किसी भी लोन पर टैप करें।", desc: "आप पूरी EMI शेड्यूल, किए गए भुगतान, बकाया बैलेंस और ब्याज देख सकते हैं।" },
          ],
          note: "नया ऋण देने से पहले उधारी के ऋण इतिहास देखना एक अच्छा अभ्यास है — यह आपको बताता है कि वे कितने विश्वसनीय हैं।"
        },
        {
          icon: "🗑️", title: "उधारी को हटाएं",
          steps: [
            { label: "उधारी की प्रोफाइल पेज पर जाएं।", desc: "Borrowers में उसे ढूंढें और नाम पर टैप करें।" },
            { label: "'More' मेनू (तीन बिंदु) पर टैप करें।", desc: "'Remove Borrower' चुनें।" },
            { label: "हटाने की पुष्टि करें।", desc: "कन्फर्मेशन डायलॉग में 'Remove' पर टैप करें।" },
          ],
          note: "उधारी को हटाने से उनका ऋण इतिहास मिटता नहीं — यह केवल सक्रिय सूची से हटा देता है। सभी रिकॉर्ड सुरक्षित रहते हैं।"
        },
      ]
    },
    recordingLoans: {
      title: "ऋण दर्ज करना",
      desc: "ऋण बनाना माइक्रोफ्लो प्रो का मूल है। यह गाइड आपको बताती है कि नया ऋण कैसे सेट करें, ब्याज दर और अवधि कैसे कॉन्फ़िगर करें, और भुगतान ट्रैकिंग कैसे शुरू करें।",
      lessons: [
        {
          icon: "💰", title: "नया ऋण बनाएं",
          steps: [
            { label: "होम स्क्रीन से 'Loans' पर टैप करें।", desc: "यह आपके सभी लोन दिखाता है — एक्टिव, पेंडिंग और पूरे हुए।" },
            { label: "'+' बटन पर टैप करें।", desc: "'New Loan' फॉर्म खुलेगा।" },
            { label: "उधारी चुनें।", desc: "अपनी उधारी सूची से चुनें। यदि नहीं है, तो पहले 'Add New Borrower' पर टैप करके प्रोफाइल बनाएं।" },
            { label: "ऋण की राशि डालें।", desc: "जितना पैसा आप उधार दे रहे हैं (उदाहरण: ₹10,000)।" },
            { label: "ब्याज दर सेट करें।", desc: "वार्षिक ब्याज दर प्रतिशत में (उदाहरण: 12% प्रति वर्ष)।" },
            { label: "ब्याज का प्रकार चुनें।", desc: "फ्लैट: हर महीने समान ब्याज। रिड्यूसिंग: बची हुई राशि पर ब्याज (कुल ब्याज कम)।" },
            { label: "ऋण की अवधि सेट करें।", desc: "ऋण कितने महीने चलता है (उदाहरण: 12 महीने)।" },
            { label: "कलेक्शन की आवृत्ति चुनें।", desc: "रोजावर, हफ्तावर, या मासिक — उधारी कितनी बार भुगतान करेगा।" },
            { label: "पहली EMI की तारीख सेट करें।", desc: "वो तारीख चुनें जब पहला भुगतान देय होगा।" },
            { label: "समीक्षा करें और 'Create Loan' दबाएं।", desc: "EMI शेड्यूल अपने आप बन जाती है — आप हर किस्त की राशि और तारीख देखेंगे।" },
          ],
          note: "The EMI schedule shows every installment with its due date and amount. View it anytime from the loan detail page."
        },
        {
          icon: "🧮", title: "ब्याज गणना को समझें",
          steps: [
            { label: "किसी भी एक्टिव लोन को खोलें।", desc: "Loans → जिस लोन को समझना है, उस पर टैप करें।" },
            { label: "EMI शेड्यूल देखें।", desc: "हर पंक्ति में किस्त संख्या, देय तारीख, EMI राशि, मूलधन भाग, ब्याज भाग और बची हुई राशि दिखती है।" },
            { label: "फ्लैट बनाम रिड्यूसिंग की तुलना करें।", desc: "फ्लैट ब्याज: हर महीने समान कुल ब्याज। रिड्यूसिंग: ब्याज समय के साथ कम होता है क्योंकि मूलधन चुका जा रहा है।" },
            { label: "कुल ब्याज जांचें।", desc: "शेड्यूल के नीचे पूरे ऋण अवधि के लिए कुल ब्याज दिखेगा।" },
          ],
          note: "रिड्यूसिंग बैलेंस आमतौर पर उधारियों के लिए बेहतर होता है (कुल ब्याज कम) और आपको दिखाता है कि किसी भी बिंदु पर आपने कितना ब्याज कमाया है।"
        },
        {
          icon: "✏️", title: "एक्टिव लोन को संपादित करें",
          steps: [
            { label: "जिस लोन को संपादित करना है, उसे खोलें।", desc: "Loans → लोन पर टैप करें।" },
            { label: "'Edit' बटन पर टैप करें।", desc: "आप ब्याज दर, अवधि या कलेक्शन आवृत्ति बदल सकते हैं।" },
            { label: "'Save' पर टैप करें।", desc: "EMI शेड्यूल अपने आप पुनर्गणना हो जाती है।" },
          ],
          note: "ब्याज दर या अवधि बदलते समेत सावधान रहें — यह भविष्य की सभी EMIs को पुनर्गणना कर देगा। पुराने भुगतान प्रभावित नहीं होंगे।"
        },
        {
          icon: "⏸️", title: "लोन को रोकें या बंद करें",
          steps: [
            { label: "जिस लोन को प्रबंधित करना है, उसे खोलें।", desc: "Loans → लोन पर टैप करें।" },
            { label: "'More' मेनू (तीन बिंदु) पर टैप करें।", desc: "आपको Pause, Resume, या Close लोन के विकल्प दिखेंगे।" },
            { label: "जब पूरी भुगतान हो जाए तो 'Close Loan' चुनें।", desc: "यह लोन को पूर्ण के रूप में मार्क करता है और इसे आपके लोन इतिहास में स्थानांतरित करता है।" },
          ],
          note: "लोन को बंद करना स्थायी है। बंद करने से पहले यह सुनिश्चित करें कि सभी बकाया EMIs का भुगतान हो चुका है।"
        },
      ]
    },
    trackingRepayments: {
      title: "किस्तें ट्रैक करना",
      desc: "भुगतान दर्ज करने से ही आपके बही-खाते सटीक रहते हैं। यह गाइड आपको बताती है कि भुगतान कैसे दर्ज करें, बकाया बैलेंस कैसे देखें और ब्याज कमाई का हिसाब कैसे रखें।",
      lessons: [
        {
          icon: "💵", title: "भुगतान दर्ज करें",
          steps: [
            { label: "Loans टैब पर जाएं।", desc: "जिस एक्टिव लोन के लिए भुगतान दर्ज करना है, उसे ढूंढें।" },
            { label: "लोन पर टैप करें।", desc: "यह EMI शेड्यूल के साथ लोन विवरण पेज खोलेगा।" },
            { label: "'Record Payment' पर टैप करें।", desc: "भुगतान विवरण डालने के लिए फॉर्म खुलेगा।" },
            { label: "भुगतान की राशि डालें।", desc: "पूरी EMI राशि या आंशिक भुगतान डाल सकते हैं।" },
            { label: "भुगतान का मोड चुनें।", desc: "नकद, UPI, या बैंक ट्रांसफर।" },
            { label: "नोट जोड़ें (वैकल्पिक)।", desc: "उदाहरण: '2 दिन देर से भुगतान' या 'आंशिक भुगतान'।" },
            { label: "'Save' पर टैप करें।", desc: "भुगतान दर्ज हो जाता है और बकाया बैलेंस अपने आप अपडेट हो जाता है।" },
          ],
          note: "एसएमएस रसीद उधारी को अपने आप भेजी जाती है यदि SMS सक्षम हो। EMI शेड्यूल भुगतान को दर्शाते हुए अपडेट हो जाता है।"
        },
        {
          icon: "📊", title: "बकाया बैलेंस की जांच करें",
          steps: [
            { label: "Loans टैब पर जाएं।", desc: "सभी एक्टिव लोन यहां सूचीबद्ध हैं।" },
            { label: "'Outstanding' कॉलम देखें।", desc: "यह दिखाता है कि उधारी को आपसे कितना पैसा बाकी है।" },
            { label: "किसी भी लोन पर टैप करें।", desc: "आप पूरी किस्त शेड्यूल, किए गए भुगतान और बची हुई राशि देखेंगे।" },
          ],
          note: "बकाया बैलेंस हर भुगतान के बाद अपने आप अपडेट होता है। कोई मैन्युअल गणना की जरूरत नहीं।"
        },
        {
          icon: "📈", title: "ब्याज कमाई का हिसाब रखें",
          steps: [
            { label: "किसी भी एक्टिव लोन को खोलें।", desc: "Loans → लोन पर टैप करें।" },
            { label: "EMI शेड्यूल की जांच करें।", desc: "हर किस्त में ब्याज का भाग दिखता है — यह उस अवधि की आपकी कमाई है।" },
            { label: "कुल ब्याज कमाई देखें।", desc: "शेड्यूल के नीचे अब तक कुल ब्याज और पूरे लोन टर्म के लिए पूर्वानुमानित कुल ब्याज दिखेगा।" },
          ],
          note: "ब्याज आपकी चुनी हुई दर और प्रकार (फ्लैट या रिड्यूसिंग) के आधार पर अपने आप गणना की जाती है। मैन्युअल गणना की जरूरत नहीं।"
        },
        {
          icon: "⏰", title: "देरी या चूक के भुगतान का सामना करें",
          steps: [
            { label: "EMI शेड्यूल में देरी वाली किस्तों की जांच करें।", desc: "बकाया EMIs लाल रंग में हाइलाइट की जाती हैं।" },
            { label: "उधारी से संपर्क करें।", desc: "उनकी प्रोफाइल से मोबाइल नंबर लेकर फॉलो-अप करें।" },
            { label: "जब भुगतान मिले तो इसे दर्ज करें।", desc: "चाहे वह देर से क्यों न हो, इसे नियमित रूप से दर्ज करें — ऐप देरी को ट्रैक करता है।" },
            { label: "यदि आवश्यक हो तो रिस्ट्रक्चरिंग पर विचार करें।", desc: "उन उधारियों के लिए जो लगातार भुगतान चूकाते हैं, EMI राशि कम कर सकते हैं या लोन टर्म बढ़ा सकते हैं।" },
          ],
          note: "ऐप में देरी से भुगतान पर स्वचालित पेनल्टी नहीं होती। यदि आप लेट फी लेते हैं, तो इसे एक अलग लेनदेन के रूप में दर्ज करें।"
        },
      ]
    },
    smsReminders: {
      title: "एसएमएस रिमाइंडर",
      desc: "उधारियों को EMI देय होने से पहले स्वचालित एसएमएस रिमाइंडर भेजने के लिए सेट अप करें। मैन्युअल फॉलो-अप कम करें और भुगतान दर सुधारें।",
      lessons: [
        {
          icon: "⚙️", title: "एसएमएस रिमाइंडर सेट करें",
          steps: [
            { label: "Settings → SMS Settings पर जाएं।", desc: "Communications सेक्शन तक स्क्रॉल करें।" },
            { label: "'Due EMI Reminders' चालू करें।", desc: "यह सभी एक्टिव लोन के लिए स्वचालित रिमाइंडर भेजता है।" },
            { label: "रिमाइंडर का समय सेट करें।", desc: "उस समय चुनें जब रिमाइंडर भेजना है — उदाहरण: सुबह 9:00 बजे।" },
            { label: "कितने दिन पहले भेजें, चुनें।", desc: "देय होने से 1, 2, या 3 दिन पहले।" },
            { label: "'Save Settings' पर टैप करें।", desc: "अब रिमाइंडर अपने आप भेजे जाएंगे।" },
          ],
          note: "एसएमएस आपके फोन की SIM कार्ड से भेजा जाता है। अपनी SIM में पर्याप्त बैलेंस रखें। कोई बाहरी SMS सर्विस नहीं — यह पूरी तरह से फ्री है।"
        },
        {
          icon: "📝", title: "रिमाइंडर संदेश कस्टमाइज करें",
          steps: [
            { label: "Settings → SMS Settings पर जाएं।", desc: "Reminder Templates सेक्शन तक स्क्रॉल करें।" },
            { label: "रिमाइंडर संदेश संपादित करें।", desc: "{name}, {amount}, {due_date}, और {loan_id} जैसे प्लेसहोल्डर का उपयोग करें।" },
            { label: "संदेश पूर्वावलोकन करें।", desc: "देखें कि संदेश उधारी को भेजने पर कैसा दिखेगा।" },
            { label: "'Save Template' पर टैप करें।", desc: "आपका कस्टम संदेश भविष्य के सभी रिमाइंडर के लिए उपयोग किया जाएगा।" },
          ],
          note: "संदेश छोटे और फ्रेंडली रखें। डिफ़ॉल्ट: 'नमस्ते {name}, आपकी EMI ₹{amount} {due_date} को देय है। कृपया भुगतान करें।'"
        },
        {
          icon: "📱", title: "मैन्युअल रिमाइंडर भेजें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "जिस उधारी को रिमाइंडर भेजना है, उसे ढूंढें।" },
            { label: "उधारी के नाम पर टैप करें।", desc: "यह उनकी प्रोफाइल पेज खोलेगा।" },
            { label: "'Send Reminder' पर टैप करें।", desc: "एक SMS तुरंत भेज दी जाती है डिफ़ॉल्ट या कस्टम रिमाइंडर संदेश के साथ।" },
          ],
          note: "वन-ऑफ फॉलो-अप के लिए मैन्युअल रिमाइंडर का उपयोग करें, जैसे किसी उधारी ने भुगतान चूका है।"
        },
        {
          icon: "🔕", title: "विशिष्ट उधारियों के लिए ऑप्ट-आउट",
          steps: [
            { label: "उधारी की प्रोफाइल खोलें।", desc: "Borrowers → उधारी पर टैप करें।" },
            { label: "'SMS Settings' पर टैप करें।", desc: "आपको SMS रिमाइंडर के लिए एक टॉगल दिखेगा।" },
            { label: "इस उधारी के लिए SMS बंद करें।", desc: "वे स्वचालित रिमाइंडर प्राप्त नहीं करेंगे, लेकिन मैन्युअल भेज सकते हैं।" },
          ],
          note: "अपने उधारियों की पसंद का सम्मान करें। यदि कोई रिमाइंडर नहीं पाना चाहता है, तो उसके लिए SMS टॉगल बंद कर दें।"
        },
      ]
    },
    portfolioInsights: {
      title: "अपने पोर्टफोलियो को समझें",
      desc: "आपका पोर्टफोलियो आपकी पूरी उधारिक गतिविधि का पूरा चित्र है। यह गाइड आपको मुख्य संख्याओं को समझने में मदद करती है — कुल दिया गया, बकाया, ब्याज कमाई और भुगतान दर।",
      lessons: [
        {
          icon: "🏦", title: "अपना पोर्टफोलियो सारांश देखें",
          steps: [
            { label: "होम स्क्रीन से Portfolio टैब पर जाएं।", desc: "यह आपके उधारिक व्यवसाय का पूर्ण अवलोकन देता है।" },
            { label: "मुख्य संख्याएं जांचें।", desc: "कुल दिया गया (Total Lent), बकाया (Outstanding), कुल ब्याज कमाई (Interest Earned) और एक्टिव लोन ऊपर दिखाए गए हैं।" },
            { label: "अधिक विवरण के लिए नीचे स्क्रॉल करें।", desc: "आपको भुगतान दर, उधारी वर्गीकरण और मासिक रुझान दिखेंगे।" },
          ],
          note: "ये संख्याएं भुगतान दर्ज करने के साथ रीयल-टाइम अपडेट होती हैं। कोई मैन्युअल गणना की जरूरत नहीं।"
        },
        {
          icon: "📊", title: "संख्याओं को समझें",
          steps: [
            { label: "कुल दिया गया (Total Lent)।", desc: "आपने जितना कुल पैसा उधार दिया है — एक्टिव, पूरे हुए और डिफॉल्टेड लोन सभी शामिल।" },
            { label: "बकाया राशि (Outstanding)।", desc: "सभी एक्टिव लोन में आपको कितना पैसा अभी बाकी है। भुगतान होने के साथ यह कम होता जाता है।" },
            { label: "ब्याज कमाई (Interest Earned)।", desc: "आपने अब तक कुल कितना ब्याज कमाया है। यह आपकी उधारिक से कमाई है।" },
            { label: "भुगतान दर (Repayment Rate)।", desc: "उन EMIs का प्रतिशत जो समय पर चुकाए गए हैं। उच्च दर मतलब आपके उधारी विश्वसनीय हैं।" },
          ],
          note: "अपनी भुगतान दर को महीने के आधार पर ट्रैक करें — यह आपके उधारिक पोर्टफोलियो के स्वास्थ का सबसे अच्छा संकेतक है।"
        },
        {
          icon: "📈", title: "मासिक रुझान और रिपोर्ट",
          steps: [
            { label: "Portfolio टैब पर जाएं।", desc: "Trends सेक्शन तक स्क्रॉल करें।" },
            { label: "मासिक चार्ट देखें।", desc: "देखें कि आपकी उधारिक, भुगतान और ब्याज कमाई समय के साथ कैसे बदल रही है।" },
            { label: "तारीख की सीमा द्वारा फिल्टर करें।", desc: "किसी विशेष महीने या तिमाही के लिए विस्तृत संख्याएं देखने के लिए चुनें।" },
          ],
          note: "अपनी उधारिक की योजना बनाने के लिए मासिक रुझान का उपयोग करें।"
        },
        {
          icon: "🎯", title: "अपनी भुगतान दर सुधारें",
          steps: [
            { label: "स्लो पेयर्स की पहचान करें।", desc: "Portfolio टैब में बकाया EMI वाले उधारियों के लिए जांच करें।" },
            { label: "जल्दी फॉलो-अप करें।", desc: "उधारियों को देय तारीख से पहले एसएमएस रिमाइंडर भेजकर प्रेरित करें।" },
            { label: "ऋण की शर्तों की समीक्षा करें।", desc: "यदि उधारी लगातार कठिनाई का सामना करते हैं, तो EMI राशि कम करने या लोन टर्म बढ़ाने पर विचार करें।" },
            { label: "रिश्ते बनाएं।", desc: "सबसे अच्छी भुगतान दर आपके उधारियों को अच्छी तरह से जानने से आती है।" },
          ],
          note: "अच्छी भुगतान दर (85% से ऊपर) मतलब आपका उधारिक व्यवसाय स्वस्थ है। 70% से कम होने पर समीक्षा की जरूरत हो सकती है।"
        },
      ]
    },
  },

  hi: {
    common: {
      allGuides: "सभी मार्गदर्शिकाएँ", backToHome: "होम", documentation: "दस्तावेज़ (Docs)",
      quickLinks: "त्वरित लिंक्स", portalGuides: "मार्गदर्शिकाएँ", watchVideo: "वीडियो देखें",
      openGuide: "गाइड खोलें", stepsTitle: "चरण-दर-चरण मार्गदर्शिका", lessons: "पाठ",
      portals: "गाइड", youtube: "यूट्यूब", selectPortal: "एक मार्गदर्शिका चुनें",
      openGuideAction: "गाइड खोलें", subscribe: "सब्सक्राइब", popularGuides: "लोकप्रिय गाइड्स",
      youtubeCtaTitle: "वीडियो ट्यूटोरियल उपलब्ध हैं",
      youtubeCtaDesc: "हर विषय के लिए विस्तृत वीडियो ट्यूटोरियल। सरल, आसान चरणों में समझाया गया है। नए वीडियो की जानकारी पाने के लिए हमारे यूट्यूब चैनल को सब्सक्राइब करें।",
    },
    home: {
      title: "दस्तावेज़", subtitle: "वीडियो ट्यूटोरियल के साथ चरण-दर-चरण गाइड",
      desc: "माइक्रोफ्लो प्रो — व्यक्तिगत पैसे उधार देने वालों के लिए सरल बही-खाता टूल। ऋण देना, किस्तें लेना, और ब्याज कमाना ट्रैक करें। ये गाइड हर फीचर को कवर करते हैं।",
      portals: {
        admin: { title: "शुरुआत करें", desc: "अकाउंट बनाएं, प्रोफाइल सेट करें, और अपना पहला उधारी जोड़ें।" },
        manager: { title: "उधारियों का प्रबंधन", desc: "उधारियों की जानकारी जोड़ें, संपर्क विवरण, और ऋण इतिहास देखें।" },
        agent: { title: "ऋण दर्ज करना", desc: "उधारियों के लिए ऋण बनाएं, ब्याज दर, अवधि और राशि सेट करें।" },
        customer: { title: "किस्तें ट्रैक करना", desc: "भुगतान दर्ज करें, बकाया देखें, और अपने ब्याज कमाई का हिसाब रखें।" },
      },
      topics: [
        { label: "📱 ऐप डाउनलोड और लॉगिन", path: "/docs/getting-started" },
        { label: "👤 अपना पहला उधारी जोड़ें", path: "/docs/managing-borrowers" },
        { label: "💰 अपना पहला ऋण बनाएं", path: "/docs/recording-loans" },
        { label: "📊 किस्त भुगतान दर्ज करें", path: "/docs/tracking-repayments" },
        { label: "📨 एसएमएस रिमाइंडर सेट करें", path: "/docs/sms-reminders" },
        { label: "📈 अपने पोर्टफोलियो को समझें", path: "/docs/portfolio-insights" },
      ]
    },
    gettingStarted: {
      title: "शुरुआत करें",
      desc: "माइक्रोफ्लो प्रो में नया हैं? यह गाइड आपके अकाउंट सेटअप, लेंडर प्रोफाइल बनाने और पहले उधारी को जोड़ने के बारे में हर चीज बताती है। इसमें लगभग 5 मिनट लगेंगे।",
      lessons: [
        {
          icon: "📲", title: "ऐप डाउनलोड करें",
          steps: [
            { label: "अपने फोन के ऐप स्टोर खोलें।", desc: "Google Play Store (Android) या App Store (iOS) पर 'MicroFlow Pro' सर्च करें।" },
            { label: "'Install' पर टैप करें।", desc: "ऐप लगभग 45 MB का है।" },
            { label: "डाउनलोड होने पर ऐप खोलें।", desc: "वेलकम स्क्रीन में 'Sign In' और 'Create Account' दिखेंगे।" },
          ]
        },
        {
          icon: "✍️", title: "अकाउंट बनाएं",
          steps: [
            { label: "'Create Account' पर टैप करें।", desc: "फॉर्म में नाम, फोन, ईमेल, पासवर्ड मांगा जाएगा।" },
            { label: "अपना विवरण भरें।", desc: "पूरा नाम, 10 अंकों का मोबाइल, ईमेल, पासवर्ड (8+ अक्षर) डालें।" },
            { label: "नियम स्वीकार करें।", desc: "Terms of Service और Privacy Policy स्वीकार करें।" },
            { label: "'Create Account' दबाएं।", desc: "वेरिफिकेशन ईमेल का लिंक क्लिक करें, फिर साइन इन करें।" },
          ],
          note: "ईमेल वेरीफाई होने के बाद अकाउंट तुरंत तैयार। कोई ट्रायल नहीं — सीधे उधार देना शुरू करें।"
        },
        {
          icon: "👤", title: "अपना प्रोफाइल सेट करें",
          steps: [
            { label: "Settings पर जाएं।", desc: "मेनू आइकन (ऊपर दाईं ओर) पर टैप करें।" },
            { label: "अपना विवरण भरें।", desc: "नाम, फोन, ईमेल और प्रोफाइल फोटो जोड़ें।" },
            { label: "अपनी पसंद सेट करें।", desc: "भाषा, डार्क मोड, बायोमेट्रिक लॉगिन।" },
          ],
          note: "Settings से कभी भी अपडेट करें। प्रोफाइल निजी है — केवल आप ही देख सकते हैं।"
        },
        {
          icon: "🧑", title: "अपना पहला उधारी जोड़ें",
          steps: [
            { label: "'Borrowers' टैब पर जाएं।", desc: "होम स्क्रीन से नीचे 'Borrowers' पर टैप करें।" },
            { label: "'+' बटन पर टैप करें।", desc: "'Add Borrower' फॉर्म खुलेगा।" },
            { label: "उधारी का विवरण डालें।", desc: "पूरा नाम, मोबाइल नंबर, पता, वैकल्पिक नोट।" },
            { label: "'Save Borrower' पर टैप करें।", desc: "उधारी जुड़ जाता है। अब ऋण बना सकते हैं।" },
          ],
          note: "जितने चाहें उतने उधारी जोड़ें — कोई प्लान सीमा नहीं। मोबाइल नंबर सही हो — SMS रिमाइंडर के लिए उपयोग होता है।"
        },
        {
          icon: "🔔", title: "एसएमएस रिमाइंडर चालू करें (वैकल्पिक)",
          steps: [
            { label: "Settings → SMS Settings पर जाएं।", desc: "Communications सेक्शन तक स्क्रॉल करें।" },
            { label: "'Due EMI Reminders' चालू करें।", desc: "उधारियों को EMI देय होने से पहले स्वचालित रिमाइंडर भेजता है।" },
            { label: "रिमाइंडर का समय सेट करें।", desc: "उदाहरण: सुबह 9:00 बजे।" },
          ],
          note: "एसएमएस आपके फोन की SIM से भेजा जाता है। कोई बाहरी SMS सर्विस या लागत नहीं। अपनी SIM में पर्याप्त बैलेंस रखें।"
        },
      ]
    },
    managingBorrowers: {
      title: "उधारियों का प्रबंधन",
      desc: "उधारी वे लोग हैं जिनसे आप पैसा उधार देते हैं। यह गाइड आपको बताती है कि उधारी प्रोफाइल कैसे जोड़ें, संपादित करें और प्रबंधित करें — संपर्क विवरण, ऋण इतिहास और भुगतान रिकॉर्ड सहित।",
      lessons: [
        {
          icon: "➕", title: "नया उधारी जोड़ें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "होम स्क्रीन से 'Borrowers' पर टैप करें।" },
            { label: "'+' बटन पर टैप करें।", desc: "'Add Borrower' फॉर्म खुलेगा।" },
            { label: "उधारी का पूरा नाम डालें।", desc: "यह नाम सभी दस्तावेजों और रसीदों पर दिखेगा।" },
            { label: "मोबाइल नंबर डालें।", desc: "एसएमएस रिमाइंडर के लिए उपयोग होता है।" },
            { label: "पता (वैकल्पिक)।", desc: "अपने रिकॉर्ड के लिए उपयोगी।" },
            { label: "नोट (वैकल्पिक)।", desc: "उदाहरण: रिश्ता, पेशा।" },
            { label: "'Save' पर टैप करें।", desc: "उधारी सूची में जुड़ जाता है।" },
          ],
          note: "एसएमएस भेजने के लिए केवल मोबाइल नंबर आवश्यक है। सही नंबर डालें।"
        },
        {
          icon: "✏️", title: "उधारी के विवरण संपादित करें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "जिस उधारी को बदलना है, उसे ढूंढें।" },
            { label: "उधारी के नाम पर टैप करें।", desc: "प्रोफाइल पेज खुलेगा।" },
            { label: "'Edit' बटन पर टैप करें।", desc: "नाम, मोबाइल, पता और नोट बदलें।" },
            { label: "'Save' पर टैप करें।", desc: "बदलाव तुरंत सेव हो जाते हैं।" },
          ],
          note: "मोबाइल नंबर बदलने से उनके सभी एक्टिव लोन और रिमाइंडर भी अपडेट हो जाएंगे।"
        },
        {
          icon: "📋", title: "उधारी के ऋण इतिहास देखें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "जिस उधारी की जांच करना है, नाम पर टैप करें।" },
            { label: "नीचे स्क्रॉल करके ऋण इतिहास देखें।", desc: "सभी लोन (एक्टिव, पूरे हुए, डिफॉल्टेड) सूचीबद्ध हैं।" },
            { label: "किसी भी लोन पर टैप करें।", desc: "EMI शेड्यूल, भुगतान, बकाया बैलेंस और ब्याज देखें।" },
          ],
          note: "नया ऋण देने से पहले इतिहास देखना अच्छा अभ्यास है — यह बताता है कि वे कितने विश्वसनीय हैं।"
        },
        {
          icon: "🗑️", title: "उधारी को हटाएं",
          steps: [
            { label: "उधारी की प्रोफाइल पेज पर जाएं।", desc: "Borrowers में उसे ढूंढें और नाम पर टैप करें।" },
            { label: "'More' मेनू (तीन बिंदु) पर टैप करें।", desc: "'Remove Borrower' चुनें।" },
            { label: "पुष्टि करें।", desc: "डायलॉग में 'Remove' पर टैप करें।" },
          ],
          note: "हटाने से ऋण इतिहास मिटता नहीं — सभी रिकॉर्ड सुरक्षित रहते हैं।"
        },
      ]
    },
    recordingLoans: {
      title: "ऋण दर्ज करना",
      desc: "ऋण बनाना माइक्रोफ्लो प्रो का मूल है। यह गाइड आपको बताती है कि नया ऋण कैसे सेट करें, ब्याज दर और अवधि कैसे कॉन्फ़िगर करें।",
      lessons: [
        {
          icon: "💰", title: "नया ऋण बनाएं",
          steps: [
            { label: "होम स्क्रीन से 'Loans' पर टैप करें।", desc: "सभी लोन दिखते हैं — एक्टिव, पेंडिंग, पूरे हुए।" },
            { label: "'+' बटन पर टैप करें।", desc: "'New Loan' फॉर्म खुलेगा।" },
            { label: "उधारी चुनें।", desc: "सूची से चुनें। यदि नहीं है, तो पहले 'Add New Borrower' से प्रोफाइल बनाएं।" },
            { label: "ऋण की राशि डालें।", desc: "जितना पैसा उधार दे रहे हैं (उदाहरण: ₹10,000)।" },
            { label: "ब्याज दर सेट करें।", desc: "वार्षिक ब्याज दर प्रतिशत में (उदाहरण: 12% प्रति वर्ष)।" },
            { label: "ब्याज का प्रकार चुनें।", desc: "फ्लैट: हर महीने समान ब्याज। रिड्यूसिंग: बची हुई राशि पर ब्याज (कुल ब्याज कम)।" },
            { label: "ऋण की अवधि सेट करें।", desc: "ऋण कितने महीने चलता है (उदाहरण: 12 महीने)।" },
            { label: "कलेक्शन की आवृत्ति चुनें।", desc: "रोजावर, हफ्तावर, या मासिक।" },
            { label: "पहली EMI की तारीख सेट करें।", desc: "वो तारीख जब पहला भुगतान देय होगा।" },
            { label: "'Create Loan' दबाएं।", desc: "EMI शेड्यूल अपने आप बन जाती है।" },
          ],
          note: "EMI शेड्यूल हर किस्त के साथ देय तारीख और राशि दिखाती है। लोन विवरण पेज से कभी भी देखें।"
        },
        {
          icon: "🧮", title: "ब्याज गणना को समझें",
          steps: [
            { label: "किसी भी एक्टिव लोन को खोलें।", desc: "Loans → जिस लोन पर टैप करें।" },
            { label: "EMI शेड्यूल देखें।", desc: "हर पंक्ति में किस्त संख्या, देय तारीख, EMI राशि, मूलधन, ब्याज और बची हुई राशि दिखती है।" },
            { label: "फ्लैट बनाम रिड्यूसिंग की तुलना करें।", desc: "फ्लैट: हर महीने समान कुल ब्याज। रिड्यूसिंग: ब्याज समय के साथ कम होता है।" },
            { label: "कुल ब्याज जांचें।", desc: "शेड्यूल के नीचे पूरे ऋण के लिए कुल ब्याज दिखेगा।" },
          ],
          note: "रिड्यूसिंग बैलेंस आमतौर पर उधारियों के लिए बेहतर होता है।"
        },
        {
          icon: "✏️", title: "एक्टिव लोन को संपादित करें",
          steps: [
            { label: "लोन को खोलें।", desc: "Loans → लोन पर टैप करें।" },
            { label: "'Edit' पर टैप करें।", desc: "ब्याज दर, अवधि या कलेक्शन आवृत्ति बदलें।" },
            { label: "'Save' पर टैप करें।", desc: "EMI शेड्यूल अपने आप पुनर्गणना हो जाती है।" },
          ],
          note: "ब्याज दर/अवधि बदलने से भविष्य की EMIs पुनर्गणना होती है। पुराने भुगतान प्रभावित नहीं।"
        },
        {
          icon: "⏸️", title: "लोन को रोकें या बंद करें",
          steps: [
            { label: "लोन को खोलें।", desc: "Loans → लोन पर टैप करें।" },
            { label: "'More' मेनू पर टैप करें।", desc: "Pause, Resume, या Close विकल्प दिखेंगे।" },
            { label: "पूरी भुगतान होने पर 'Close Loan' चुनें।", desc: "लोन पूर्ण के रूप में मार्क हो जाता है।" },
          ],
          note: "लोन बंद करना स्थायी है। सभी बकाया EMIs का भुगतान होने से पहले बंद न करें।"
        },
      ]
    },
    trackingRepayments: {
      title: "किस्तें ट्रैक करना",
      desc: "भुगतान दर्ज करने से आपके बही-खाते सटीक रहते हैं। यह गाइड आपको बताती है कि भुगतान कैसे दर्ज करें, बकाया बैलेंस कैसे देखें और ब्याज कमाई का हिसाब कैसे रखें।",
      lessons: [
        {
          icon: "💵", title: "भुगतान दर्ज करें",
          steps: [
            { label: "Loans टैब पर जाएं।", desc: "जिस एक्टिव लोन के लिए भुगतान दर्ज करना है, उसे खोलें।" },
            { label: "लोन पर टैप करें।", desc: "EMI शेड्यूल के साथ विवरण पेज खुलेगा।" },
            { label: "'Record Payment' पर टैप करें।", desc: "भुगतान विवरण डालने का फॉर्म खुलेगा।" },
            { label: "भुगतान की राशि डालें।", desc: "पूरी EMI या आंशिक भुगतान डालें।" },
            { label: "भुगतान का मोड चुनें।", desc: "नकद, UPI, या बैंक ट्रांसफर।" },
            { label: "नोट जोड़ें (वैकल्पिक)।", desc: "उदाहरण: '2 दिन देर से भुगतान'।" },
            { label: "'Save' पर टैप करें।", desc: "भुगतान दर्ज हो जाता है और बकाया अपने आप अपडेट होता है।" },
          ],
          note: "एसएमएस रसीद उधारी को अपने आप भेजी जाती है। EMI शेड्यूल भुगतान को दर्शाते हुए अपडेट हो जाता है।"
        },
        {
          icon: "📊", title: "बकाया बैलेंस की जांच करें",
          steps: [
            { label: "Loans टैब पर जाएं।", desc: "सभी एक्टिव लोन सूचीबद्ध हैं।" },
            { label: "'Outstanding' कॉलम देखें।", desc: "उधारी को आपसे कितना पैसा बाकी है, यह दिखाता है।" },
            { label: "किसी भी लोन पर टैप करें।", desc: "EMI शेड्यूल, भुगतान और बची हुई राशि देखें।" },
          ],
          note: "बकाया बैलेंस हर भुगतान के बाद अपने आप अपडेट होता है। कोई मैन्युअल गणना नहीं।"
        },
        {
          icon: "📈", title: "ब्याज कमाई का हिसाब रखें",
          steps: [
            { label: "किसी भी एक्टिव लोन को खोलें।", desc: "Loans → लोन पर टैप करें।" },
            { label: "EMI शेड्यूल की जांच करें।", desc: "हर किस्त में ब्याज का भाग — यह आपकी कमाई है।" },
            { label: "कुल ब्याज कमाई देखें।", desc: "शेड्यूल के नीचे अब तक कुल ब्याज और पूर्वानुमानित कुल दिखेगा।" },
          ],
          note: "ब्याज आपकी चुनी हुई दर के आधार पर अपने आप गणना की जाती है। मैन्युअल गणना की जरूरत नहीं।"
        },
        {
          icon: "⏰", title: "देरी या चूक के भुगतान का सामना करें",
          steps: [
            { label: "EMI शेड्यूल में देरी वाली किस्तों की जांच करें।", desc: "बकाया EMIs लाल रंग में हाइलाइट की जाती हैं।" },
            { label: "उधारी से संपर्क करें।", desc: "मोबाइल नंबर लेकर फॉलो-अप करें।" },
            { label: "जब भुगतान मिले तो दर्ज करें।", desc: "देर से हो तो भी दर्ज करें — ऐप देरी ट्रैक करता है।" },
            { label: "यदि आवश्यक हो तो रिस्ट्रक्चरिंग पर विचार करें।", desc: "लगातार चूकने पर EMI कम या टर्म बढ़ा सकते हैं।" },
          ],
          note: "ऐप में देरी पर स्वचालित पेनल्टी नहीं होती। लेट फी लेते हैं तो अलग लेनदेन के रूप में दर्ज करें।"
        },
      ]
    },
    smsReminders: {
      title: "एसएमएस रिमाइंडर",
      desc: "उधारियों को EMI देय होने से पहले स्वचालित एसएमएस रिमाइंडर भेजने के लिए सेट अप करें। मैन्युअल फॉलो-अप कम करें और भुगतान दर सुधारें।",
      lessons: [
        {
          icon: "⚙️", title: "एसएमएस रिमाइंडर सेट करें",
          steps: [
            { label: "Settings → SMS Settings पर जाएं।", desc: "Communications सेक्शन तक स्क्रॉल करें।" },
            { label: "'Due EMI Reminders' चालू करें।", desc: "सभी एक्टिव लोन के लिए स्वचालित रिमाइंडर भेजता है।" },
            { label: "रिमाइंडर का समय सेट करें।", desc: "उदाहरण: सुबह 9:00 बजे।" },
            { label: "कितने दिन पहले भेजें, चुनें।", desc: "देय होने से 1, 2, या 3 दिन पहले।" },
            { label: "'Save Settings' पर टैप करें।", desc: "अब रिमाइंडर अपने आप भेजे जाएंगे।" },
          ],
          note: "एसएमएस आपके फोन की SIM से भेजा जाता है। कोई बाहरी SMS सर्विस नहीं — यह फ्री है।"
        },
        {
          icon: "📝", title: "रिमाइंडर संदेश कस्टमाइज करें",
          steps: [
            { label: "Settings → SMS Settings पर जाएं।", desc: "Reminder Templates सेक्शन तक स्क्रॉल करें।" },
            { label: "संदेश संपादित करें।", desc: "{name}, {amount}, {due_date}, {loan_id} प्लेसहोल्डर का उपयोग करें।" },
            { label: "संदेश पूर्वावलोकन करें।", desc: "देखें कि संदेश कैसा दिखेगा।" },
            { label: "'Save Template' पर टैप करें।", desc: "कस्टम संदेश भविष्य के सभी रिमाइंडर के लिए उपयोग किया जाएगा।" },
          ],
          note: "संदेश छोटे और फ्रेंडली रखें। डिफ़ॉल्ट: 'नमस्ते {name}, आपकी EMI ₹{amount} {due_date} को देय है।'"
        },
        {
          icon: "📱", title: "मैन्युअल रिमाइंडर भेजें",
          steps: [
            { label: "Borrowers टैब पर जाएं।", desc: "जिस उधारी को रिमाइंडर भेजना है, उसे ढूंढें।" },
            { label: "उधारी के नाम पर टैप करें।", desc: "प्रोफाइल पेज खुलेगा।" },
            { label: "'Send Reminder' पर टैप करें।", desc: "SMS तुरंत भेज दी जाती है।" },
          ],
          note: "वन-ऑफ फॉलो-अप के लिए मैन्युअल रिमाइंडर का उपयोग करें।"
        },
        {
          icon: "🔕", title: "विशिष्ट उधारियों के लिए ऑप्ट-आउट",
          steps: [
            { label: "उधारी की प्रोफाइल खोलें।", desc: "Borrowers → उधारी पर टैप करें।" },
            { label: "'SMS Settings' पर टैप करें।", desc: "SMS रिमाइंडर का टॉगल दिखेगा।" },
            { label: "इस उधारी के लिए SMS बंद करें।", desc: "स्वचालित रिमाइंडर प्राप्त नहीं करेंगे, लेकिन मैन्युअल भेज सकते हैं।" },
          ],
          note: "उधारियों की पसंद का सम्मान करें। रिमाइंडर नहीं चाहते तो SMS बंद कर दें।"
        },
      ]
    },
    portfolioInsights: {
      title: "अपने पोर्टफोलियो को समझें",
      desc: "आपका पोर्टफोलियो आपकी पूरी उधारिक गतिविधि का पूरा चित्र है। कुल दिया गया, बकाया, ब्याज कमाई और भुगतान दर — यह गाइड मुख्य संख्याओं को समझने में मदद करती है।",
      lessons: [
        {
          icon: "🏦", title: "पोर्टफोलियो सारांश देखें",
          steps: [
            { label: "होम स्क्रीन से Portfolio टैब पर जाएं।", desc: "आपके उधारिक व्यवसाय का पूर्ण अवलोकन।" },
            { label: "मुख्य संख्याएं जांचें।", desc: "कुल दिया गया, बकाया, कुल ब्याज कमाई और एक्टिव लोन ऊपर दिखाए गए हैं।" },
            { label: "नीचे स्क्रॉल करें।", desc: "भुगतान दर, उधारी वर्गीकरण और मासिक रुझान दिखेंगे।" },
          ],
          note: "ये संख्याएं रीयल-टाइम अपडेट होती हैं। कोई मैन्युअल गणना नहीं।"
        },
        {
          icon: "📊", title: "संख्याओं को समझें",
          steps: [
            { label: "कुल दिया गया (Total Lent)।", desc: "जितना कुल पैसा उधार दिया है — सभी लोन शामिल।" },
            { label: "बकाया (Outstanding)।", desc: "अभी कितना पैसा बाकी है। भुगतान होने पर कम होता जाता है।" },
            { label: "ब्याज कमाई (Interest Earned)।", desc: "अब तक कुल कितना ब्याज कमाया है। यह आपकी कमाई है।" },
            { label: "भुगतान दर (Repayment Rate)।", desc: "उन EMIs का प्रतिशत जो समय पर चुकाए गए हैं। उच्च दर = विश्वसनीय उधारी।" },
          ],
          note: "भुगतान दर महीने के आधार पर ट्रैक करें — यह पोर्टफोलियो स्वास्थ का सबसे अच्छा संकेतक है।"
        },
        {
          icon: "📈", title: "मासिक रुझान और रिपोर्ट",
          steps: [
            { label: "Portfolio टैब पर जाएं।", desc: "Trends सेक्शन तक स्क्रॉल करें।" },
            { label: "मासिक चार्ट देखें।", desc: "उधारिक, भुगतान और ब्याज कमाई समय के साथ कैसे बदल रही है।" },
            { label: "तारीख की सीमा द्वारा फिल्टर करें।", desc: "विशेष महीने या तिमाही के लिए चुनें।" },
          ],
          note: "मासिक रुझान से उधारिक की योजना बनाएं।"
        },
        {
          icon: "🎯", title: "अपनी भुगतान दर सुधारें",
          steps: [
            { label: "स्लो पेयर्स की पहचान करें।", desc: "Portfolio टैब में बकाया EMI वाले उधारियों को ढूंढें।" },
            { label: "जल्दी फॉलो-अप करें।", desc: "उधारियों को देय तारीख से पहले रिमाइंडर भेजें।" },
            { label: "ऋण की शर्तों की समीक्षा करें।", desc: "कठिनाई हो तो EMI कम या टर्म बढ़ाएं।" },
            { label: "रिश्ते बनाएं।", desc: "उधारियों को अच्छी तरह से जानें — संपर्क विवरण अपडेट रखें।" },
          ],
          note: "अच्छी भुगतान दर (85% से ऊपर) = स्वस्थ व्यवसाय। 70% से कम = समीक्षा जरूरी।"
        },
      ]
    },
  },

  bn: {
    common: {
      allGuides: "সব নির্দেশিকা", backToHome: "হোম", documentation: "নথিপত্র (Docs)",
      quickLinks: "দ্রুত লিঙ্কসমূহ", portalGuides: "গাইডসমূহ", watchVideo: "ভিডিও দেখুন",
      openGuide: "গাইড খুলুন", stepsTitle: "ধাপে ধাপে নির্দেশিকা", lessons: "অধ্যায়",
      portals: "গাইড", youtube: "ইউটিউব", selectPortal: "একটি গাইড বেছে নিন",
      openGuideAction: "গাইড খুলুন", subscribe: "সাবস্ক্রাইব", popularGuides: "জনপ্রিয় গাইডসমূহ",
      youtubeCtaTitle: "ভিডিও টিউটোরিয়াল উপলব্ধ",
      youtubeCtaDesc: "প্রতিটি বিষয়ের জন্য বিস্তারিত ভিডিও টিউটোরিয়াল। সহজ ও সরল ধাপে ব্যাখ্যা করা হয়েছে। নতুন ভিডিওর আপডেট পেতে আমাদের ইউটিউব চ্যানেলটি সাবস্ক্রাইব করুন।",
    },
    home: {
      title: "নথিপত্র", subtitle: "ভিডিও টিউটোরিয়াল সহ ধাপে ধাপে গাইড",
      desc: "মাইক্রোফ্লো প্রো — স্বতন্ত্র টাকা ধার দানকারীর জন্য সাধারণ বহি-খাতা টুল। ঋণ দেওয়া, কিস্তি আদায় এবং সুদ কমানো ট্র্যাক করুন। এই গাইডগুলি প্রতিটি বৈশিষ্ট্য কভার করে।",
      portals: {
        admin: { title: "শুরু করুন", desc: "অ্যাকাউন্ট তৈরি করুন, প্রোফাইল সেট করুন এবং আপনার第一个 ধারক যোগ করুন।" },
        manager: { title: "ধারকদের পরিচালনা", desc: "ধারকদের তথ্য যোগ করুন, যোগাযোগ বিবরণ এবং ঋণ ইতিহাস দেখুন।" },
        agent: { title: "ঋণ নিবন্ধন", desc: "ধারকদের জন্য ঋণ তৈরি করুন, সুদের হার, সময়সীমা এবং পরিমাণ সেট করুন।" },
        customer: { title: "কিস্তি ট্র্যাকিং", desc: "পেমেন্ট লগ করুন, বকেয়া দেখুন এবং আপনার সুদ আয় অকারণ করুন।" },
      },
      topics: [
        { label: "📱 অ্যাপ ডাউনলোড ও লগইন", path: "/docs/getting-started" },
        { label: "👤 আপনার প্রথম ধারক যোগ করুন", path: "/docs/managing-borrowers" },
        { label: "💰 আপনার প্রথম ঋণ তৈরি করুন", path: "/docs/recording-loans" },
        { label: "📊 কিস্তি পরিশোধ লগ করুন", path: "/docs/tracking-repayments" },
        { label: "📨 এসএমএস রিমাইন্ডার সেট করুন", path: "/docs/sms-reminders" },
        { label: "📈 আপনার পোর্টফোলিও বুঝুন", path: "/docs/portfolio-insights" },
      ]
    },
    gettingStarted: {
      title: "শুরু করুন",
      desc: "মাইক্রোফ্লো প্রো-তে নতুন? এই গাইডটি আপনার অ্যাকাউন্ট সেটআপ, লেন্ডার প্রোফাইল তৈরি এবং প্রথম ধারক যোগ করার সবকিছু কভার করে। এতে প্রায় ৫ মিনিট লাগবে।",
      lessons: [
        {
          icon: "📲", title: "অ্যাপ ডাউনলোড করুন",
          steps: [
            { label: "আপনার ফোনের অ্যাপ স্টোর খুলুন।", desc: "Google Play Store (Android) বা App Store (iOS)-এ 'MicroFlow Pro' সার্চ করুন।" },
            { label: "'Install' এ ট্যাপ করুন।", desc: "অ্যাপটি প্রায় ৪৫ এমবি।" },
            { label: "ডাউনলোড শেষ হলে অ্যাপ খুলুন।", desc: "ওয়েলকাম স্ক্রিনে 'Sign In' ও 'Create Account' দেখবেন।" },
          ]
        },
        {
          icon: "✍️", title: "অ্যাকাউন্ট তৈরি করুন",
          steps: [
            { label: "'Create Account' এ ট্যাপ করুন।", desc: "ফর্মে নাম, ফোন, ইমেইল, পাসওয়ার্ড চাওয়া হবে।" },
            { label: "আপনার বিবরণ পূরণ করুন।", desc: "পূর্ণ নাম, ১০ অঙ্কের মোবাইল, বৈধ ইমেইল, পাসওয়ার্ড (৮+ অক্ষর)।" },
            { label: "নিয়ম গৃহীত করুন।", desc: "Terms of Service ও Privacy Policy গৃহীত করুন।" },
            { label: "'Create Account' চাপুন।", desc: "ভেরিফিকেশন ইমেইলের লিঙ্কে ক্লিক করুন, এরপর সাইন ইন করুন।" },
          ],
          note: "ইমেইল ভেরিফিকেশনের পরে অ্যাকাউন্ট প্রস্তুত। কোনো সংস্থা সেটআপ বা ট্রায়াল নেই — সরাসরি ঋণ দেওয়া শুরু করুন।"
        },
        {
          icon: "👤", title: "আপনার প্রোফাইল সেট করুন",
          steps: [
            { label: "Settings-এ যান।", desc: "মেনু আইকন (উপর ডানদিকে) এ ট্যাপ করুন।" },
            { label: "আপনার বিবরণ পূরণ করুন।", desc: "নাম, ফোন, ইমেইল এবং চাইলে প্রোফাইল ছবি।" },
            { label: "পছন্দ সেট করুন।", desc: "ভাষা, ডার্ক মোড, বায়োমেট্রিক লগইন।" },
          ],
          note: "Settings থেকে যেকোনো সময় আপডেট করুন। প্রোফাইল গোপন — শুধুমাত্র আপনিই দেখতে পারবেন।"
        },
        {
          icon: "🧑", title: "আপনার প্রথম ধারক যোগ করুন",
          steps: [
            { label: "'Borrowers' ট্যাবে যান।", desc: "হোম স্ক্রিন থেকে নিচে 'Borrowers' এ ট্যাপ করুন।" },
            { label: "'+' বোতামে ট্যাপ করুন।", desc: "'Add Borrower' ফর্ম খুলবে।" },
            { label: "ধারকের বিবরণ লিখুন।", desc: "পূর্ণ নাম, মোবাইল নম্বর, ঠিকানা, ঐচ্ছিক নোট।" },
            { label: "'Save Borrower' চাপুন।", desc: "ধারকটি যোগ হয়ে যাবে। এখন ঋণ তৈরি করতে পারেন।" },
          ],
          note: "যত চান তত ধারক যোগ করুন — কোনো প্ল্যান সীমা নেই। মোবাইল নম্বর সঠিক হ contacting — এসএমএস রিমাইন্ডারের জন্য।"
        },
        {
          icon: "🔔", title: "এসএমএস রিমাইন্ডার চালু করুন (ঐচ্ছিক)",
          steps: [
            { label: "Settings → SMS Settings-এ যান।", desc: "Communications সেকশন পর্যন্ত স্ক্রল করুন।" },
            { label: "'Due EMI Reminders' চালু করুন।", desc: "স্বয়ংক্রিয় রিমাইন্ডার পাঠাবে।" },
            { label: "সময় সেট করুন।", desc: "উদাহরণ: সকাল ৯:০০ ঘটিকা।" },
          ],
          note: "এসএমএস আপনার ফোনের SIM থেকে পাঠানো হয়। কোনো বহিঃস্থ সেবা বা খরচ নেই। SIM এ পর্যাপ্ত ব্যালেন্স রাখুন।"
        },
      ]
    },
    managingBorrowers: {
      title: "ধারকদের পরিচালনা",
      desc: "ধারকরা সেই লোকেরা যাদের থেকে আপনি টাকা ধার নেন। এই গাইডটি আপনাকে বলে কিভাবে ধারক প্রোফাইল যোগ, সম্পাদনা এবং পরিচালনা করতে হয় — যোগাযোগ বিবরণ, ঋণ ইতিহাস ও পরিশোধ রেকর্ড সহ।",
      lessons: [
        {
          icon: "➕", title: "নতুন ধারক যোগ করুন",
          steps: [
            { label: "Borrowers ট্যাবে যান।", desc: "হোম স্ক্রিন থেকে 'Borrowers' এ ট্যাপ করুন।" },
            { label: "'+' বোতামে ট্যাপ করুন।", desc: "'Add Borrower' ফর্ম খুলবে।" },
            { label: "ধারকের পূর্ণ নাম লিখুন।", desc: "এই নাম সব ঋণ দলিল ও রসিদের উপর দৃশ্য হবে।" },
            { label: "মোবাইল নম্বর লিখুন।", desc: "এসএমএস রিমাইন্ডার ও রসিদের জন্য ব্যবহৃত হয়।" },
            { label: "ঠিকানা লিখুন (ঐচ্ছিক)।", desc: "আপনার নিজের রেকর্ডের জন্য।" },
            { label: "নোট যোগ করুন (ঐচ্ছিক)।", desc: "যেমন: সম্পর্ক, পেশা।" },
            { label: "'Save' চাপুন।", desc: "ধারকটি আপনার তালিকায় যোগ হয়ে যাবে।" },
          ],
          note: "এসএমএস পাঠানোর জন্য কেবল মোবাইল নম্বর প্রয়োজন। সঠিক নম্বর দিন।"
        },
        {
          icon: "✏️", title: "ধারকের বিবরণ সম্পাদনা করুন",
          steps: [
            { label: "Borrowers ট্যাবে যান।", desc: "যে ধারককে সম্পাদনা করতে চান, তাকে খুঁজুন।" },
            { label: "ধারকের নামে ট্যাপ করুন।", desc: "প্রোফাইল পেজ খুলবে।" },
            { label: "'Edit' বোতামে ট্যাপ করুন।", desc: "নাম, মোবাইল, ঠিকানা ও নোট পরিবর্তন করুন।" },
            { label: "'Save' চাপুন।", desc: "পরিবর্তনগুলি সংরক্ষিত হবে।" },
          ],
          note: "মোবাইল নম্বর পরিবর্তন করলে তার সব অ্যাক্টিভ লোন ও এসএমএস রিমাইন্ডারও আপডেট হয়ে যাবে।"
        },
        {
          icon: "📋", title: "ধারকের ঋণ ইতিহাস দেখুন",
          steps: [
            { label: "Borrowers ট্যাবে যান।", desc: "যে ধারকের পরীক্ষা করতে চান, তাকে খুঁজুন এবং নামে ট্যাপ করুন।" },
            { label: "নিচে স্ক্রল করে ঋণ ইতিহাস দেখুন।", desc: "সমস্ত ঋণ (সক্রিয়, সম্পূর্ণ, ডিফল্টেড) তালিকাভুক্ত আছে।" },
            { label: "যে কোনো ঋণের ওপর ট্যাপ করুন।", desc: "EMI সময়সূচী, পরিশোধ, বকেয়া ব্যালেন্স ও সুদ দেখতে পারবেন।" },
          ],
          note: "নতুন ঋণ দানের আগে ইতিহাস দেখা ভাল অভ্যাস — এটি বলে যে তারা কতটা বিশ্বস্ত।"
        },
        {
          icon: "🗑️", title: "ধারকটি সরান",
          steps: [
            { label: "ধারকের প্রোফাইল পেজে যান।", desc: "Borrowers-এ তাকে খুঁজুন।" },
            { label: "'More' মেনু এ ট্যাপ করুন।", desc: "'Remove Borrower' বেছে নিন।" },
            { label: "পূরণ করুন।", desc: "ডায়ালগে 'Remove' এ ট্যাপ করুন।" },
          ],
          note: "ধারকটি সরালে তার ঋণ ইতিহাস ম Asi আর নয় — সব রেকর্ড সুরক্ষিত থাকবে।"
        },
      ]
    },
    recordingLoans: {
      title: "ঋণ নিবন্ধন",
      desc: "ঋণ তৈরি করা মাইক্রোফ্লো প্রোর মূল কাজ। নতুন ঋণ সেট আপ, সুদের হার ও সময়সীমা কনফিগার এবং পরিশোধ ট্র্যাকিং শুরু করার গাইড।",
      lessons: [
        {
          icon: "💰", title: "নতুন ঋণ তৈরি করুন",
          steps: [
            { label: "'Loans'-এ ট্যাপ করুন।", desc: "সব ঋণ দেখাবে — সক্রিয়, মুলতুবি, সম্পূর্ণ।" },
            { label: "'+' বোতামে ট্যাপ করুন।", desc: "'New Loan' ফর্ম খুলবে।" },
            { label: "ধারক বেছে নিন।", desc: "যদি ধারক না থাকে, প্রথমে 'Add New Borrower' এ ট্যাপ করুন।" },
            { label: "ঋণের পরিমাণ লিখুন।", desc: "উদাহরণ: ₹১০,০০০।" },
            { label: "সুদের হার সেট করুন।", desc: "বার্ষিক সুদ হার শতাংশে (উদাহরণ: ১২% প্রতি বছর)।" },
            { label: "সুদের ধরন বেছে নিন।", desc: "ফ্ল্যাট: প্রতি মাসে সমান সুদ। রিডিউসিং: বাকি Somerset পর সুদ গণনা।" },
            { label: "ঋণের সময়সীমা সেট করুন।", desc: "কত মাস চলবে (উদाहরণ: ১২ মাস)।" },
            { label: "কালেকশনের frecuensy বেছে নিন।", desc: "দৈনিক, সাপ্তাহিক, বা মাসিক।" },
            { label: "প্রথম EMI তারিখ সেট করুন।", desc: "তারিখ বেছে নিন যখন প্রথম পরিশোধ দেয়যোগ্য।" },
            { label: "'Create Loan' চাপুন।", desc: "EMI সময়সূচী স্বয়ংক্রিয়ভাবে তৈরি হয়ে যাবে।" },
          ],
          note: "EMI সময়সূচী প্রতিটি কিস্তির সাথে দেয়যোগ্য তারিখ ও রাশি দেখায়। যেকোনো সময় দেখতে পারেন।"
        },
        {
          icon: "🧮", title: "সুদের গণনা বুঝুন",
          steps: [
            { label: "সক্রিয় ঋণ খুলুন।", desc: "Loans → ঋণে ট্যাপ করুন।" },
            { label: "EMI সময়সূচী দেখুন।", desc: "প্রতিটি সারিতে কিস্তি নম্বর, তারিখ, রাশি, মূলধন, সুদ এবং বাকি Somerset দেখায়।" },
            { label: "ফ্ল্যাট বনাম রিডিউসিং তুলনা করুন।", desc: "ফ্ল্যাট: প্রতি মাসে সমান মোট সুদ। রিডিউসিং: সময়ের সাথে সুদ কমে।" },
            { label: "মোট সুদ দেখুন।", desc: "সময়সূচীর নিচে মোট সুদ দেখতে পাবেন।" },
          ],
          note: "রিডিউসিং ব্যালেন্স সাধারণত ভাল (মোট সুদ কম)।"
        },
        {
          icon: "✏️", title: "সক্রিয় ঋণ সম্পাদনা করুন",
          steps: [
            { label: "ঋণটি খুলুন।", desc: "Loans → ঋণে ট্যাপ করুন।" },
            { label: "'Edit' এ ট্যাপ করুন।", desc: "সুদের হার, সময়সীমা বা frecuensy পরিবর্তন করুন।" },
            { label: "'Save' চাপুন।", desc: "EMI সময়সূচী পুনরায় গণনা হবে।" },
          ],
          note: "ব্যয় দর/সময়সীমা পরিবর্তনের সময় সাবধান — ভবিষ্যতের EMIs পুনরায় গণনা হবে। পুরাতন পেমেন্ট প্রভাবিত হবে না।"
        },
        {
          icon: "⏸️", title: "ঋণ বন্ধ করুন",
          steps: [
            { label: "ঋণটি খুলুন।", desc: "Loans → ঋণে ট্যাপ করুন।" },
            { label: "'More' মেনু এ ট্যাপ করুন।", desc: "Pause, Resume, বা Close দেখাবে।" },
            { label: "সম্পূর্ণ পরিশোধ হলে 'Close Loan' বেছে নিন।", desc: "ঋণ সম্পূর্ণভাবে চিহ্নিত হবে।" },
          ],
          note: "বন্ধ করা স্থায়ী। সব বকেয়া EMI পরিশোধ হলে বন্ধ করুন।"
        },
      ]
    },
    trackingRepayments: {
      title: "কিস্তি ট্র্যাকিং",
      desc: "পরিশোধ লগ করার মাধ্যমে আপনার বহি-খাতা সঠিক থাকে। গাইড shows you how to log payments, view outstanding balances, and track interest earnings.",
      lessons: [
        {
          icon: "💵", title: "পরিশোধ লগ করুন",
          steps: [
            { label: "Loans ট্যাবে যান।", desc: "সক্রিয় ঋণ খুঁজুন।" },
            { label: "ঋণের ওপর ট্যাপ করুন।", desc: "EMI সময়সূচী সহ বিবরণ পেজ খুলবে।" },
            { label: "'Record Payment' এ ট্যাপ করুন।", desc: "পেমেন্ট ফর্ম খুলবে।" },
            { label: "রাশি লিখুন।", desc: "সম্পূর্ণ EMI বা আংশিক পেমেন্ট।" },
            { label: "মোড বেছে নিন।", desc: "নগদ, UPI, বা ব্যাংক ট্রান্সফার।" },
            { label: "নোট যোগ করুন (ঐচ্ছিক)।", desc: "যেমন: '২ দিন দেরিতে'।" },
            { label: "'Save' চাপুন।", desc: "পেমেন্ট লগ হয়ে যায়, বকেয়া স্বয়ংক্রিয়ভাবে আপডেট হয়।" },
          ],
          note: "এসএমএস রসিদ স্বয়ংক্রিয়ভাবে যায়। EMI সময়সূচী আপডেট হয়।"
        },
        {
          icon: "📊", title: "বকেয়া ব্যালেন্স পরীক্ষা করুন",
          steps: [
            { label: "Loans ট্যাবে যান।", desc: "সব সক্রিয় ঋণ তালিকাভুক্ত।" },
            { label: "'Outstanding' কলাম দেখুন।", desc: "ধারককে কত টাকা বাকি আছে।" },
            { label: "ঋণের ওপর ট্যাপ করুন।", desc: "সম্পূর্ণ সময়সূচী, পরিশোধ, বাক Somerset দেখুন।" },
          ],
          note: "বকেয়া স্বয়ংক্রিয়ভাবে আপডেট হয়। কোনো ম্যানুয়াল গণনা নেই।"
        },
        {
          icon: "📈", title: "সুদ আয় অকারণ করুন",
          steps: [
            { label: "সক্রিয় ঋণ খুলুন।", desc: "Loans → ঋণে ট্যাপ করুন।" },
            { label: "EMI সময়সূচী দেখুন।", desc: "প্রতিটি কিস্তিতে সুদের অংশ — এটি আপনার আয়।" },
            { label: "মোট সুদ দেখুন।", desc: "নিচে এতকালে মোট সুদ ও অনুমানিত মোট দৃশ্য।" },
          ],
          note: "সুদ স্বয়ংক্রিয়ভাবে গণনা হয়। ম্যানুয়াল গণনা প্রয়োজন নেই।"
        },
        {
          icon: "⏰", title: "দেরি বা চূকালো भुগতान",
          steps: [
            { label: "বকায়া EMI খুঁজুন।", desc: "লাল রঙে হাইলাইটেড।" },
            { label: "ধারকে संपर्क করুন।", desc: "মোবাইল নম্বর দিয়ে ফোলো-আপ।" },
            { label: "পেমেন্ট মিললে লগ করুন।", desc: "দেরির পরও লগ করুন — অ্যাপ দেরি ট্র্যাক করে।" },
            { label: "প্রয়োজনে রিস্ট্রাকচারিং।", desc: "য们 লগাতার চুকাতে পারে, তাদের EMI কম বা টার্ম বাঢ়ান।" },
          ],
          note: "অ্যাপে দেরিতে স্বয়ংক্রিয় পেনাল্টি নেই। লেট ফీ ল egal면 আলग লেনদেন হিসেবে লগ করুন।"
        },
      ]
    },
    smsReminders: {
      title: "এসএমএস রিমাইন্ডার",
      desc: "ঋণ দেয়ার আগে স্বয়ংক্রিয় এসএমএস রিমাইন্ডার পাঠান। ম্যানুয়াল ফোলো-আপ কমিয়ে ভুলTransaction Påmind।",
      lessons: [
        {
          icon: "⚙️", title: "এসএমএস রিমাইন্ডার সেট করুন",
          steps: [
            { label: "Settings → SMS Settings এ যান।", desc: "Communications সেকশন পর্যন্ত স্ক্রল করুন।" },
            { label: "'Due EMI Reminders' চালু করুন।", desc: "সব সক্রিয় লনের জন্য স্বয়ংক্রিয় রিমাইন্ডার পাঠাবে।" },
            { label: "সময় সেট করুন।", desc: "উদাহরণ: সকাল ৯:০০ ঘটিকা।" },
            { label: "কত দিন আগে পাঠাবে, বেছে নিন।", desc: "১, ২, বা ৩ দিন আগে।" },
            { label: "'Save Settings' চাপুন।", desc: "রিমাইন্ডার স্বয়ংক্রিয়ভাবে পাঠানো হবে।" },
          ],
          note: "এসএমএস আপনার ফোনের SIM থেকে যায়। কোনো বাহির SMS সার্ভিস নেই — এটি মুক্ত।"
        },
        {
          icon: "📝", title: "রিমাইন্ডার বার্তা কাস্টমাইজ করুন",
          steps: [
            { label: "Settings → SMS Settings এ যান।", desc: "Reminder Templates পর্যন্ত স্ক্রল করুন।" },
            { label: "বার্তা সম্পাদনা করুন।", desc: "{name}, {amount}, {due_date}, {loan_id} ব্যবহার করুন।" },
            { label: "পূর্বদৃশ্য দেখুন।", desc: "বার্তা কেমন দৃশ্য হবে তা দেখুন।" },
            { label: "'Save Template' চাপুন।", desc: "কাস্টম বার্তা ভবিষ্যতের সব রিমাইন্ডারে ব্যবহৃত হবে।" },
          ],
          note: "বার্তা ছোট ও বন্ধুত্বপূর্ণ রাখুন। ডিফল্ট: 'নমস্কার {name}, আপনার EMI ₹{amount} {due_date} তারিখে দেয়যোগ্য।'"
        },
        {
          icon: "📱", title: "ম্যানুয়াল রিমাইন্ডার পাঠান",
          steps: [
            { label: "Borrowers ট্যাবে যান।", desc: "ধারককে খুঁজুন।" },
            { label: "নামে ট্যাপ করুন।", desc: "প্রোফাইল পেজ খুলবে।" },
            { label: "'Send Reminder' চাপুন।", desc: "SMS তুরান্ত পাঠানো হয়।" },
          ],
          note: "ওয়ান-অফ ফোলো-আপের জন্য ম্যানুয়াল রিমাইন্ডার ব্যবহার করুন।"
        },
        {
          icon: "🔕", title: "বিশেষ ধারকদের জন্য অপ্ট-আউট",
          steps: [
            { label: "ধারকের প্রোফাইল খুলুন।", desc: "Borrowers → ধারক।" },
            { label: "'SMS Settings' এ ট্যাপ করুন।", desc: "রিমাইন্ডার টগল দৃশ্য হবে।" },
            { label: "এই ধারকের জন্য SMS বন্ধ করুন।", desc: "স্বয়ংক্রিয় রিমাইন্ডার পাবেন না, কিন্তু ম্যানুয়াল পাঠাতে পারবেন।" },
          ],
          note: "ধারকদের পছন্দের সম্মান করুন। রিমাইন্ডার চান না ত면 SMS বন্ধ করুন।"
        },
      ]
    },
    portfolioInsights: {
      title: "আপনার পোর্টফোলিও বুঝুন",
      desc: "আপনার পোর্টফোলিও আপনার সম্পূর্ণ ঋণ কার্যক্রমের চিত্র। মোট দিয়agram Somerset, বকেয়া, সুদ আয় ও পরিশোধ হার — মূল সংখ্যা বুঝুন।",
      lessons: [
        {
          icon: "🏦", title: "পোর্টফোলিও সারাংশ দেখুন",
          steps: [
            { label: "Portfolio ট্যাবে যান।", desc: "ঋণ ব্যবসার সম্পূর্ণ পরিদৃশ্য।" },
            { label: "মূলসংখ্যা পরীক্ষা করুন।", desc: "মোট দিয়agram, বকেয়া, মোট সুদ আয় ও সক্রিয় ঋণ উপরে দৃশ্য।" },
            { label: "নিচে স্ক্রল করুন।", desc: "পরিশোধ হার, ধারক বিভাজন ও মাসিক প্রবণতা দেখুন।" },
          ],
          note: "সংখ্যাগুলো রিয়েল-টাইম আপডেট হয়। কোনো ম্যানুয়াল গণনা নেই।"
        },
        {
          icon: "📊", title: "সংখ্যাগুলো বুঝুন",
          steps: [
            { label: "মোট দিয় Somerset (Total Lent)।", desc: "মোট ঋণের পরিমাণ — সব ধরনের লোন Included।" },
            { label: "বকেয়া (Outstanding)।", desc: "বর্তমানে আপনার কত টাকা বাকি আছে।" },
            { label: "সুদ আয় (Interest Earned)।", desc: "অব দিয়ে মোট কত সুদ কমিয়েছেন।" },
            { label: "পরিশোধ হার (Repayment Rate)।", desc: "সময় পর চুকানো EMI-এর শতাংশ। উচ্চ হার = বিশ্বস্ত ধারক।" },
          ],
          note: "পরিশোধ হার মাসিকভাবে ট্র্যাক করুন — এটি পোর্টফোলিও স্বাস্থ্যের সেরা সংকেতক।"
        },
        {
          icon: "📈", title: "মাসিক প্রবণতা ও রিপোর্ট",
          steps: [
            { label: "Portfolio ট্যাবে যান।", desc: "Trends সেকশন পর্যন্ত স্ক্রল করুন।" },
            { label: "মাসিক চার্ট দেখুন।", desc: "ঋণ, পরিশোধ ও সুদ আয় সময়ের সাথে কীভাবে বদলছে।" },
            { label: "তারিখ সীমায় ফিল্টার করুন।", desc: "বিশেষ মাস বা ত্রিমাসীর জন্য বিস্তারিত সংখ্যা দেখুন।" },
          ],
          note: "মাসিক প্রবণতা দিয়ে ঋণ পরিকল্পনা করুন।"
        },
        {
          icon: "🎯", title: "পরিশোধ হার উন্নত করুন",
          steps: [
            { label: "ধীর支付কারীদের চিহ্নিত করুন।", desc: "Portfolio ট্যাবে বকেয়া EMI ওয়ার দারকদের খুঁজুন।" },
            { label: "শীঘ্রই ফোলো-আপ করুন।", desc: "দেয়ার তারিখের আগে এসএমএস রিমাইন্ডার পাঠান।" },
            { label: "ঋণের শর্ত পর্যালোচনা করুন।", desc: "কঠিন হলে EMI কম বা টার্ম বাঢ়ান।" },
            { label: "সম্পর্ক তৈরি করুন।", desc: "ধারকদের ভালভাবে জানুন — যোগাযোগ বিবরণ আপডেট রাখুন।" },
          ],
          note: "ভাল পরিশোধ হার (৮৫%+) = স্বাস্থ্যকর ঋণ ব্যবসা। ৭০% কম হলে পর্যালোচনা প্রয়োজন।"
        },
      ]
    },
  },
};
