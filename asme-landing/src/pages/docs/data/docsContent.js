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
        { label: "📈 View Analytics & Reports", path: "/docs/executive-admin" },
        { label: "📨 Configure SMS Alerts", path: "/docs/executive-admin" },
        { label: "📍 Agent Live Tracking", path: "/docs/branch-manager" },
        { label: "🔐 Force Password Reset", path: "/docs/executive-admin" }
      ]
    },
    executiveAdmin: {
      title: "Executive Admin Guide",
      desc: "As an Executive Admin, you hold full organization-level control. Access branch registries, add staff, manage loan products, configure system settings, and inspect organization-wide reports.",
      lessons: [
        {
          icon: "🚀",
          title: "Getting Started — First Login",
          steps: [
            { label: "Open the URL sent in your Welcome Email.", desc: "Use a secure browser like Chrome or Safari." },
            { label: "Enter your registered Email Address and password.", desc: "If you forgot your password, click 'Forgot Password' directly below the input." },
            { label: "Access the Home Dashboard to view organization summaries." }
          ],
          note: "Always update your profile details under settings immediately after your first login."
        },
        {
          icon: "🏢",
          title: "Setup Organization Preferences",
          steps: [
            { label: "Select 'Settings' from the left navigation panel.", desc: "Then choose 'Organization Settings'." },
            { label: "Enter legal name, billing details (GST/PAN), and official address.", desc: "Set locale settings to match your regional timezone." },
            { label: "Scroll down to 'Branding Settings' and upload your logo to sync visual theme across all staff portals." }
          ],
          note: "Logo updates can take up to 2 minutes to sync across all portals."
        },
        {
          icon: "👥",
          title: "Add and Manage Branches",
          steps: [
            { label: "Navigate to the 'Branches' module via the side menu.", desc: "This lists all currently active offices." },
            { label: "Click 'Add Branch' in the top right corner.", desc: "A modal registry form will appear." },
            { label: "Enter Branch Name, Branch Code, geography/location details.", desc: "Assign an active Branch Manager from the list." },
            { label: "Save to create. The code will serve as a system filter." }
          ],
          note: "Each branch must have a unique code. Example: BM-SWAR-01"
        },
        {
          icon: "👤",
          title: "Invite and Register Staff",
          steps: [
            { label: "Open the 'Staff' section in the database overlay.", desc: "This displays current agents, managers, and admins." },
            { label: "Tap 'Add Staff Member' to open registration.", desc: "Fill in name, phone number, and official email." },
            { label: "Define user role (Branch Manager or Collection Agent).", desc: "Select their assigned physical branch." },
            { label: "Click 'Send Invitation' to email registration link to the user." }
          ],
          note: "Staff will need to set their primary password by clicking the verification link in their email."
        },
        {
          icon: "📊",
          title: "Generate and Export Reports",
          steps: [
            { label: "Select the 'Reports' page under settings.", desc: "Choose your target category: collections, savings, or disbursals." },
            { label: "Apply Filters (Branch context, Staff context, Date range).", desc: "Select daily, weekly, or monthly aggregations." },
            { label: "Review charts for visual progress indicators.", desc: "Check parameters like Portfolio at Risk (PAR) and active collections." },
            { label: "Click 'Export' to download PDF/Excel reports instantly." }
          ]
        },
        {
          icon: "📨",
          title: "Manage SMS Alerts",
          steps: [
            { label: "Go to Settings > SMS Settings to configure notifications.", desc: "Verify active status under outbox providers." },
            { label: "Customize message content for receipts and reminders.", desc: "You can write placeholders like {name} and {amount}." },
            { label: "Toggle auto-send rules for collections and loan signups.", desc: "Click Save to apply." }
          ],
          note: "Automatic SMS delivery uses the custom SIM setup of the agent or the central gateway config."
        },
        {
          icon: "💳",
          title: "Billing and Plan Management",
          steps: [
            { label: "Go to Settings > Billing.", desc: "Check your current usage status." },
            { label: "To edit billing metadata, tap 'Modify billing instructions'.", desc: "You can configure payment cycles." },
            { label: "Provide new billing details or update payment options to ensure service." }
          ]
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
        { label: "📈 रिपोर्ट और चार्ट देखना", path: "/docs/executive-admin" },
        { label: "📨 एसएमएस अलर्ट सेट करना", path: "/docs/executive-admin" },
        { label: "📍 एजेंट लाइव ट्रैकिंग", path: "/docs/branch-manager" },
        { label: "🔐 पासवर्ड रीसेट करना", path: "/docs/executive-admin" }
      ]
    },
    executiveAdmin: {
      title: "मुख्य एडमिन गाइड (Executive Admin)",
      desc: "मुख्य एडमिन के रूप में, आपके पास पूरे संगठन का डेटा और नियंत्रण होता है। शाखाएं बनाना, स्टाफ जोड़ना, ब्याज दरें बदलना, और पूरे संगठन की विस्तृत रिपोर्ट देखना यहाँ सीखें।",
      lessons: [
        {
          icon: "🚀",
          title: "शुरुआत करना — पहला लॉगिन",
          steps: [
            { label: "अपने स्वागत ईमेल (Welcome Email) में दिए गए लिंक को खोलें।", desc: "क्रोम (Chrome) या सफारी जैसे सुरक्षित ब्राउज़र का उपयोग करें।" },
            { label: "अपना पंजीकृत ईमेल एड्रेस और पासवर्ड दर्ज करें।", desc: "यदि आप पासवर्ड भूल गए हैं, तो नीचे 'Forgot Password' पर क्लिक करें।" },
            { label: "एकीकृत डैशबोर्ड पर जाएं और संगठन की कुल स्थिति का जायजा लें।" }
          ],
          note: "लॉगिन करने के बाद सबसे पहले अपनी प्रोफाइल सेटिंग्स में जाकर जानकारियों को अपडेट कर लें।"
        },
        {
          icon: "🏢",
          title: "संगठन की सेटिंग्स करना",
          steps: [
            { label: "बाएं मेनू से 'Settings' (सेटिंग्स) का चयन करें।", desc: "फिर 'Organization Settings' (संगठन सेटिंग्स) चुनें।" },
            { label: "संस्था का कानूनी नाम, टैक्स विवरण (GST/PAN) और पता दर्ज करें।", desc: "अपने क्षेत्र की भाषा और समय क्षेत्र (Timezone) का चयन करें।" },
            { label: "Branding Settings में जाकर अपना लोगो लोड करें ताकि सभी स्टाफ ऐप्स का रंग-रूप बदल सके।" }
          ],
          note: "लोगो अपडेट होने में और सभी डिवाइस पर दिखने में 2 मिनट का समय लग सकता है।"
        },
        {
          icon: "👥",
          title: "शाखा (Branch) जोड़ना और संभालना",
          steps: [
            { label: "साइड मेनू से 'Branches' (शाखाएं) विकल्प पर जाएं।", desc: "यहाँ आपकी सभी शाखाओं की सूची दिखेगी।" },
            { label: "ऊपर दाईं ओर 'Add Branch' (शाखा जोड़ें) पर क्लिक करें।", desc: "एक नया फॉर्म खुलेगा।" },
            { label: "शाखा का नाम, ब्रांच कोड और उसकी जगह का विवरण लिखें।", desc: "सूची में से किसी एक स्टाफ को वहां का मैनेजर (प्रबंधक) नियुक्त करें।" },
            { label: "सुरक्षित (Save) करें। कोड का उपयोग बाद में रिपोर्ट फ़िल्टर करने के लिए किया जाएगा।" }
          ],
          note: "हर शाखा का कोड अलग (Unique) होना चाहिए। जैसे: BM-SWAR-01"
        },
        {
          icon: "👤",
          title: "नया स्टाफ सदस्य पंजीकृत करना",
          steps: [
            { label: "स्टाफ (Staff) सेक्शन खोलें और सूची देखें।", desc: "यहाँ सभी सक्रिय फील्ड एजेंट और मैनेजर दिखेंगे।" },
            { label: "'Add Staff Member' पर क्लिक करें।", desc: "उसका नाम, मोबाइल नंबर और ईमेल लिखें।" },
            { label: "स्टाफ की भूमिका चुनें (Branch Manager या Collection Agent)।", desc: "उनकी पोस्टिंग की शाखा का चयन करें।" },
            { label: "'Send Invitation' पर क्लिक करें। उन्हें ईमेल पर लॉगिन पासवर्ड सेट करने का लिंक मिलेगा।" }
          ],
          note: "स्टाफ मेंबर को अपने ईमेल पर आए लिंक पर क्लिक करके अपना पहला पासवर्ड बनाना होगा।"
        },
        {
          icon: "📊",
          title: "रिपोर्ट्स और चार्ट्स देखना",
          steps: [
            { label: "बाएं पैनल से 'Reports' विकल्प चुनें।", desc: "संग्रह (Collections), ऋण वितरण (Disbursals) या बचत का चयन करें।" },
            { label: "फ़िल्टर लागू करें (तारीख, शाखा, या किसी विशिष्ट एजेंट की रिपोर्ट)।" },
            { label: "व्यापारिक ग्राफ़ और जोखिम वाले ऋण (PAR) का विश्लेषण करें।" },
            { label: "Excel या PDF डाउनलोड करने के लिए 'Export' बटन पर क्लिक करें।" }
          ]
        },
        {
          icon: "📨",
          title: "एसएमएस (SMS) रसीद सेटिंग्स",
          steps: [
            { label: "Settings > SMS Settings पर जाएं।", desc: "चेक करें की रसीद भेजने की सुविधा एक्टिव है या नहीं।" },
            { label: "एसएमएस मैसेज का प्रारूप (Template) बदलें।", desc: "आप {name} और {amount} जैसे कोड का उपयोग कर सकते हैं।" },
            { label: "भुगतान प्राप्त होते ही ऑटो-एसएमएस भेजने का नियम चालू (Toggle ON) करें।" }
          ],
          note: "स्वचालित एसएमएस एजेंट के मोबाइल सिम या प्लेटफॉर्म के सेंट्रलाइज्ड गेटवे से भेजे जाते हैं।"
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
          desc: "অর্গানাইজেশন সেটআপ, ব্রাঞ্চ পরিচালনা, স্টাফদের তদারকি এবং বিস্তারিত রিপোর্ট ও অ্যানালিটিক্সের নিয়ন্ত্রণ।"
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
        { label: "📈 রিপোর্ট এবং চার্ট দেখা", path: "/docs/executive-admin" },
        { label: "📨 এসএমএস অ্যালার্ট সেট করা", path: "/docs/executive-admin" },
        { label: "📍 এজেন্টের লাইভ লোকেশন ট্র্যাকিং", path: "/docs/branch-manager" },
        { label: "🔐 পাসওয়ার্ড রিসেট করা", path: "/docs/executive-admin" }
      ]
    },
    executiveAdmin: {
      title: "মূল অ্যাডমিন গাইড (Executive Admin)",
      desc: "এক্সিকিউটিভ অ্যাডমিন হিসেবে আপনার কাছে পুরো অর্গানাইজেশনের সম্পূর্ণ নিয়ন্ত্রণ থাকে। নতুন ব্রাঞ্চ তৈরি করা, স্টাফদের আমন্ত্রন পাঠানো, সুদের হার নির্ধারণ এবং আর্থিক বিবরণী দেখা এখান থেকে জানুন।",
      lessons: [
        {
          icon: "🚀",
          title: "শুরু করা — প্রথম লগইন",
          steps: [
            { label: "স্বাগতম ইমেলে (Welcome Email) দেওয়া লিঙ্কটি ব্রাউজারে খুলুন।", desc: "Chrome বা Safari-র মতো সুরক্ষিত ব্রাউজার ব্যবহার করুন।" },
            { label: "আপনার রেজিস্টার্ড ইমেল এবং পাসওয়ার্ড লিখুন।", desc: "পাসওয়ার্ড ভুলে গেলে নিচে 'Forgot Password' অপশনে ক্লিক করুন।" },
            { label: "হোম ড্যাশবোর্ডে গিয়ে পুরো অর্গানাইজেশনের একটা সংক্ষিপ্ত খতিয়ান দেখে নিন।" }
          ],
          note: "প্রথমবার লগইন করার পর অবশ্যই সেটিংসের প্রোফাইল পেজে গিয়ে আপনার বিস্তারিত তথ্য আপডেট করে নিন।"
        },
        {
          icon: "🏢",
          title: "অর্গানাইজেশনের সেটিংস তৈরি",
          steps: [
            { label: "বাঁদিকের নেভিগেশন প্যানেল থেকে 'Settings' নির্বাচন করুন।", desc: "তারপর 'Organization Settings' অপশনে যান।" },
            { label: "সংস্থার আইনি নাম, করের বিবরণ (GST/PAN) এবং ঠিকানা লিখুন।", desc: "আপনার স্থানীয় ভাষা এবং সময় নির্ধারণ (Timezone) করুন।" },
            { label: "Branding Settings-এ গিয়ে সংস্থার লোগো আপলোড করুন, যা দিয়ে সমস্ত স্টাফ অ্যাপের থিম কালার বদলে যাবে।" }
          ],
          note: "লোগো আপডেট হওয়ার পর সমস্ত ব্রাঞ্চ ও স্টাফ পোর্টালে সিঙ্ক হতে ২ মিনিট পর্যন্ত সময় লাগতে পারে।"
        },
        {
          icon: "👥",
          title: "শাখা (Branch) যুক্ত ও পরিচালনা করা",
          steps: [
            { label: "বাঁদিকের মেনু থেকে 'Branches' অপশনে যান।", desc: "এখানে আপনার সমস্ত সক্রিয় শাখার তালিকা দেখাবে।" },
            { label: "ওপরে ডানদিকের কোণায় 'Add Branch'-এ ক্লিক করুন।", desc: "একটি নতুন ফর্ম চালু হবে।" },
            { label: "শাখার নাম, ব্রাঞ্চের একক কোড এবং জায়গার বিবরণ লিখুন।", desc: "তালিকা থেকে একজন ব্রাঞ্চ ম্যানেজার নিয়োগ করুন।" },
            { label: "সংরক্ষণ (Save) করুন। নির্দিষ্ট ব্রাঞ্চ কোড দিয়ে পরবর্তীতে রিপোর্ট ফিল্টার করা যাবে।" }
          ],
          note: "প্রতিটি শাখার কোড আলাদা হওয়া বাধ্যতামূলক। উদাহরণ: BM-SWAR-01"
        },
        {
          icon: "👤",
          title: "স্টাফ সদস্য যুক্ত করা",
          steps: [
            { label: "ড্যাশবোর্ড থেকে 'Staff' বিভাগটি খুলুন।", desc: "এখানে সমস্ত ম্যানেজার ও কালেকশন কর্মকর্তাদের তালিকা দেখাবে।" },
            { label: "'Add Staff Member'-এ ক্লিক করে নাম, মোবাইল নম্বর এবং ইমেল লিখুন।" },
            { label: "স্টাফের ভূমিকা সিলেক্ট করুন (Branch Manager নাকি Collection Agent)।", desc: "তাঁর জন্য নির্দিষ্ট শাখাটি নির্বাচন করুন।" },
            { label: "'Send Invitation'-এ ক্লিক করুন। তাঁর ইমেলে পাসওয়ার্ড সেট করার লিঙ্ক পাঠানো হবে।" }
          ],
          note: "স্টাফ মেম্বারকে ইমেলে পাঠানো লিঙ্কটিতে ক্লিক করে নিজের প্রথম পাসওয়ার্ড তৈরি করে নিতে হবে।"
        },
        {
          icon: "📊",
          title: "রিপোর্ট জেনারেট ও এক্সপোর্ট",
          steps: [
            { label: "বাঁদিকের প্যানেল থেকে 'Reports' পৃষ্ঠায় যান।", desc: "আপনার লক্ষ্য বিভাগ বাছুন: কালেকশন, লোন বা সেভিংস।" },
            { label: "ফিল্টার প্রয়োগ করুন (তারিখ, ব্রাঞ্চ বা কোনো নির্দিষ্ট কালেকশন এজেন্টের নাম)।" },
            { label: "চার্ট এবং লোন ঝুঁকির হার (PAR Ratio) বিশ্লেষণ করুন।" },
            { label: "Excel বা PDF ফাইল ডাউনলোড করতে 'Export' বোতামে ক্লিক করুন।" }
          ]
        },
        {
          icon: "📨",
          title: "স্বয়ংক্রিয় এসএমএস (SMS) রসিদ",
          steps: [
            { label: "Settings > SMS Settings অপশনে যান।", desc: "চেক করুন এসএমএস পাঠানোর সুবিধা চালু আছে কিনা।" },
            { label: "গ্রাহকদের কাছে পাঠানো রসিদ ও রিমাইন্ডারের এসএমএস লেখা এডিট করুন।", desc: "আপনি {name} বা {amount}-এর মতো কোড ব্যবহার করতে পারেন।" },
            { label: "কিস্তি কালেকশন হওয়ার সাথে সাথে অটো-এসএমএস পাঠানোর অপশনটি অন করুন।" }
          ],
          note: "এসএমএসগুলি মূলত এজেন্টের মোবাইল সিম বা ক্লাউড গেটওয়ের মাধ্যমে পাঠানো হয়।"
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
