import '../models/announcement.dart';

/// Lightweight, completely offline localization engine for Emergency Broadcast content.
/// Supports the 10 disaster-region languages:
/// en (English), hi (Hindi), or (Odia), bn (Bengali), as (Assamese),
/// ml (Malayalam), gu (Gujarati), mai (Maithili), brx (Bodo), te (Telugu).
class BroadcastLocalizer {
  // ---------------------------------------------------------------------------
  // 1. Pre-configured catalog for default emergency announcements
  // ---------------------------------------------------------------------------
  static const Map<String, Map<String, LocalizedContent>> announcementCatalog = {
    // Cyclone Warning (ann_1)
    'ann_1': {
      'en': LocalizedContent(
        title: 'Cyclone Warning',
        message: 'Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.',
        source: 'Disaster Response Cell',
      ),
      'hi': LocalizedContent(
        title: 'चक्रवात की चेतावनी',
        message: 'आपके क्षेत्र में भारी वर्षा और 65 किमी/घंटा तक की हवाओं की संभावना है। निर्धारित तूफान आश्रयों में जाएं।',
        source: 'आपदा प्रतिक्रिया प्रकोष्ठ',
      ),
      'or': LocalizedContent(
        title: 'ବାତ୍ୟା ସତର୍କତା',
        message: 'ଆପଣଙ୍କ ଅଞ୍ଚଳରେ ପ୍ରବଳ ବର୍ଷା ଏବଂ ୬୫ କିମି/ଘଣ୍ଟା ବେଗରେ ପବନ ବହିବାର ସମ୍ଭାବନା ଅଛି। ନିର୍ଦ୍ଧାରିତ ବାତ୍ୟା ଆଶ୍ରୟସ୍ଥଳକୁ ଯାଆନ୍ତୁ।',
        source: 'ବିପର୍ଯ୍ୟୟ ପରିଚାଳନା ପ୍ରକୋଷ୍ଠ',
      ),
      'bn': LocalizedContent(
        title: 'ঘূর্ণিঝড় সতর্কতা',
        message: 'আপনার এলাকায় ভারী বৃষ্টিপাত এবং ৬৫ কিমি/ঘন্টা পর্যন্ত বেগে বাতাসের সম্ভাবনা রয়েছে। নির্দিষ্ট ঝড় আশ্রয়কেন্দ্রে যান।',
        source: 'দুর্যোগ মোকাবিলা সেল',
      ),
      'as': LocalizedContent(
        title: 'ঘূৰ্ণীবতাহৰ সতৰ্কবাণী',
        message: 'আপোনাৰ অঞ্চলত প্ৰবল বৰষুণ আৰু ৬৫ কিমি/ঘণ্টা বেগত বতাহ বলাৰ সম্ভাৱনা আছে। নিৰ্দিষ্ট ধুমুহা আশ্ৰয় শিবিৰলৈ যাওক।',
        source: 'দূৰ্যোগ সঁহাৰি কোষ',
      ),
      'ml': LocalizedContent(
        title: 'ചുഴലിക്കാറ്റ് മുന്നറിയിപ്പ്',
        message: 'നിങ്ങളുടെ പ്രദേശത്ത് ശക്തമായ മഴയും മണിക്കൂറിൽ 65 കി.മീ വേഗതയുള്ള കാറ്റും പ്രതീക്ഷിക്കുന്നു. നിർദ്ദിഷ്ട കൊടുങ്കാറ്റ് അഭയകേന്ദ്രങ്ങളിലേക്ക് മാറുക.',
        source: 'ദുരന്ത പ്രതികരണ സെൽ',
      ),
      'gu': LocalizedContent(
        title: 'વાવાઝોડાની ચેતવણી',
        message: 'તમારા વિસ્તારમાં ભારે વરસાદ અને 65 કિમી/કલાકની ઝડપે પવન ફૂંકાવાની શક્યતા છે. નિર્ધારિત વાવાઝોડા આશ્રયસ્થાનોમાં જાઓ.',
        source: 'આપત્તિ વ્યવસ્થાપન સેલ',
      ),
      'mai': LocalizedContent(
        title: 'चक्रवातक चेतावनी',
        message: 'अहाँक क्षेत्र मे भारी वर्षा आ 65 किमी/घंटा धरि हवा चलबाक संभावना अछि। निर्धारित तूफान आश्रय मे जाउ।',
        source: 'आपदा प्रतिक्रिया प्रकोष्ठ',
      ),
      'brx': LocalizedContent(
        title: 'बारहुंखा सांग्रांथि',
        message: 'नोंथांनि ओनसोलआव गोख्रों अखा आरो घन्टायाव 65 कि.मि. बार बारनो हागौ। थि खालामखानाय बारहुंखा बास्थियाव थां।',
        source: 'खामानि खौरांगिरि बाहागो',
      ),
      'te': LocalizedContent(
        title: 'తుఫాను హెచ్చరిక',
        message: 'మీ ప్రాంతంలో భారీ వర్షం మరియు గంటకు 65 కి.మీ వేగంతో బలమైన గాలులు వీచే అవకాశం ఉంది. నిర్దేశిత తుఫాను పునరావాస కేంద్రాలకు వెళ్లండి.',
        source: 'విపత్తు ప్రతిస్పందన విభాగం',
      ),
      'mr': LocalizedContent(
        title: 'चक्रीवादळाचा इशारा',
        message: 'तुमच्या भागात मुसळधार पाऊस आणि ६५ किमी/ताशी वेगाने वारे वाहण्याची शक्यता आहे. वादळ निवारक निवाऱ्यात जा.',
        source: 'आपत्ती प्रतिसाद कक्ष',
      ),
      'ta': LocalizedContent(
        title: 'புயல் எச்சரிக்கை',
        message: 'உங்கள் பகுதியில் கனமழை மற்றும் மணிக்கு 65 கி.மீ வேகத்தில் பலத்த காற்று வீசக்கூடும். குறிப்பிட்ட புயல் நிவாரண முகாம்களுக்கு செல்லவும்.',
        source: 'பேரிடர் மேலாண்மை பிரிவு',
      ),
      'kn': LocalizedContent(
        title: 'ಚಂಡಮಾರುತದ ಮುನ್ನೆಚ್ಚರಿಕೆ',
        message: 'ನಿಮ್ಮ ಪ್ರದೇಶದಲ್ಲಿ ಭಾರಿ ಮಳೆ ಮತ್ತು ಗಂಟೆಗೆ 65 ಕಿ.ಮೀ ವೇಗದಲ್ಲಿ ಗಾಳಿ ಬೀಸುವ ನಿರೀಕ್ಷೆಯಿದೆ. ಗೊತ್ತುಪಡಿಸಿದ ಚಂಡಮಾರುತ ಆಶ್ರಯ ತಾಣಗಳಿಗೆ ತೆರಳಿ.',
        source: 'ವಿಪತ್ತು ನಿರ್ವಹಣಾ ಕೋಶ',
      ),
      'pa': LocalizedContent(
        title: 'ਚੱਕਰਵਾਤ ਚੇਤਾਵਨੀ',
        message: 'ਤੁਹਾਡੇ ਖੇਤਰ ਵਿੱਚ ਭਾਰੀ ਮੀਂਹ ਅਤੇ 65 ਕਿਲੋਮੀਟਰ/ਘੰਟੇ ਦੀ ਰਫ਼ਤਾਰ ਨਾਲ ਹਵਾਵਾਂ ਚੱਲਣ ਦੀ ਸੰਭਾਵਨਾ ਹੈ। ਤੂਫ਼ਾਨ ਆਸਰਾ ਕੇਂਦਰਾਂ ਵਿੱਚ ਜਾਓ।',
        source: 'ਆਫ਼ਤ ਪ੍ਰਤੀਕਿਰਿਆ ਸੈੱਲ',
      ),
      'ks': LocalizedContent(
        title: 'तूहफानुक ख़बरदार',
        message: 'त्वहिन्दिस जायस मंज़ ज़बरदस्त रूद त ६५ कि.मी/घंटुक वाव वयुन मुमकिन छु। महफूज़ पनाहगाहस मंज़ पचिव।',
        source: 'मुसीबत रद्दे-अमल दस्ता',
      ),
    },

    // Flood Evacuation Notice (ann_2)
    'ann_2': {
      'en': LocalizedContent(
        title: 'Flood Evacuation Notice',
        message: 'Evacuation route active via North Bypass. Relief camp #3 open at Central High School.',
        source: 'Emergency Network',
      ),
      'hi': LocalizedContent(
        title: 'बाढ़ निकासी सूचना',
        message: 'उत्तरी बाईपास के माध्यम से निकासी मार्ग सक्रिय है। सेंट्रल हाई स्कूल में राहत शिविर #3 खुला है।',
        source: 'आपातकालीन नेटवर्क',
      ),
      'or': LocalizedContent(
        title: 'ବନ୍ୟା ସ୍ଥାନାନ୍ତର ସୂଚନା',
        message: 'ଉତ୍ତର ବାଇପାସ୍ ଦେଇ ସ୍ଥାନାନ୍ତର ରାସ୍ତା କାର୍ଯ୍ୟକ୍ଷମ। ସେଣ୍ଟ୍ରାଲ୍ ହାଇସ୍କୁଲରେ ରିଲିଫ୍ କ୍ୟାମ୍ପ #୩ ଖୋଲା ଅଛି।',
        source: 'ଜରୁରୀକାଳୀନ ନେଟୱର୍କ',
      ),
      'bn': LocalizedContent(
        title: 'বন্যা উচ্ছেদ বিজ্ঞপ্তি',
        message: 'উত্তর বাইপাস দিয়ে নিরাপদ নির্গমন রুট চালু রয়েছে। সেন্ট্রাল হাই স্কুলে ত্রাণ শিবির #৩ খোলা হয়েছে।',
        source: 'জরুরি নেটওয়ার্ক',
      ),
      'as': LocalizedContent(
        title: 'বানপানীৰ পৰা স্থানান্তৰৰ জাননী',
        message: 'উত্তৰ বাইপাছেৰে স্থানান্তৰৰ পথ সক্ৰিয় হৈ আছে। চেন্ট্ৰেল হাইস্কুলত সাহায্য শিবিৰ #৩ খোলা আছে।',
        source: 'জৰুৰীকালীন নেটৱৰ্ক',
      ),
      'ml': LocalizedContent(
        title: 'പ്രളയ ഒഴിപ്പിക്കൽ അറിയിപ്പ്',
        message: 'നോർത്ത് ബൈപാസ് വഴിയുള്ള ഒഴിപ്പിക്കൽ പാത സജീവമാണ്. സെൻട്രൽ ഹൈസ്കൂളിൽ റിലീഫ് ക്യാമ്പ് #3 പ്രവർത്തിക്കുന്നു.',
        source: 'എമർജൻസി നെറ്റ്‌വർക്ക്',
      ),
      'gu': LocalizedContent(
        title: 'પૂર સ્થળાંતર સૂચના',
        message: 'ઉત્તર બાયપાસ દ્વારા સ્થળાંતર માર્ગ સક્રિય છે. સેન્ટ્રલ હાઈસ્કૂલ ખાતે રાહત કેમ્પ #3 ખુલ્લો છે.',
        source: 'ઇમરજન્સી નેટવર્ક',
      ),
      'mai': LocalizedContent(
        title: 'बाढ़ि निकासी सूचना',
        message: 'उत्तर बाईपास सं निकासी मार्ग चालू अछि। सेंट्रल हाई स्कूल मे राहत शिविर #3 खुजल अछि।',
        source: 'आपातकालीन नेटवर्क',
      ),
      'brx': LocalizedContent(
        title: 'दैबानानिफ्राय खारखारनाय खौरां',
        message: 'सा बाइपासजों खारखारनाय लामाया साख्रिथाव। सेन्ट्रेल हाइ स्कुलाव राहत खाम्प #3 खुलिना दोनबाय।',
        source: 'जायख्लं नेटवर्क',
      ),
      'te': LocalizedContent(
        title: 'వరద ఖాళీ చేయు నోటీసు',
        message: 'నార్త్ బైపాస్ ద్వారా తరలింపు మార్గం తెరిచి ఉంది. సెంట్రల్ హైస్కూల్‌లో రిలీఫ్ క్యాంప్ #3 పనిచేస్తోంది.',
        source: 'ఎమర్జెన్సీ నెట్‌వర్క్',
      ),
      'mr': LocalizedContent(
        title: 'पूर स्थलांतर सूचना',
        message: 'उत्तर बायपासमार्गे स्थलांतर मार्ग सुरू आहे. सेंट्रल हायस्कूलमध्ये मदत छावणी #३ खुली आहे.',
        source: 'आपत्कालीन नेटवर्क',
      ),
      'ta': LocalizedContent(
        title: 'வெள்ள வெளியேற்ற அறிவிப்பு',
        message: 'வடக்கு பைபாஸ் வழியான வெளியேற்ற பாதை பயன்பாட்டில் உள்ளது. சென்ட்ரல் மேல்நிலைப் பள்ளியில் நிவாரண முகாம் #3 செயல்படுகிறது.',
        source: 'அவசர நெட்வொர்க்',
      ),
      'kn': LocalizedContent(
        title: 'ಪ್ರವಾಹ ಸ್ಥಳಾಂತರ ಸೂಚನೆ',
        message: 'ಉತ್ತರ ಬೈಪಾಸ್ ಮೂಲಕ ಸ್ಥಳಾಂತರ ಮಾರ್ಗ ಕಾರ್ಯನಿರ್ವಹಿಸುತ್ತಿದೆ. ಸೆಂಟ್ರಲ್ ಹೈಸ್ಕೂಲ್‌ನಲ್ಲಿ ಪರಿಹಾರ ಶಿಬಿರ #3 ತೆರೆದಿದೆ.',
        source: 'ತುರ್ತು ನೆಟ್‌ವರ್ಕ್',
      ),
      'pa': LocalizedContent(
        title: 'ਹੜ੍ਹ ਨਿਕਾਸੀ ਸੂਚਨਾ',
        message: 'ਉੱਤਰੀ ਬਾਈਪਾਸ ਰਾਹੀਂ ਨਿਕਾਸੀ ਮਾਰਗ ਚਾਲੂ ਹੈ। ਸੈਂਟਰਲ ਹਾਈ ਸਕੂਲ ਵਿਖੇ ਰਾਹਤ ਕੈਂਪ #3 ਖੁੱਲ੍ਹਾ ਹੈ।',
        source: 'ਐਮਰਜੈਂਸੀ ਨੈੱਟਵਰਕ',
      ),
      'ks': LocalizedContent(
        title: 'सयलाब निकास सूचना',
        message: 'उत्तरी बाईपास ज़रिए निकासी वत चालू छ। सेंट्रल हाई स्कूल मंज़ राहत कैंप #३ खुला छ।',
        source: 'हंगामी नेटवर्क',
      ),
    },

    // Clean Water & Food Supply (ann_3)
    'ann_3': {
      'en': LocalizedContent(
        title: 'Clean Water & Food Supply',
        message: 'Potable water tankers and ration kits available at Community Grounds Gate 2 until 6:00 PM.',
        source: 'Relief Team',
      ),
      'hi': LocalizedContent(
        title: 'स्वच्छ जल एवं भोजन आपूर्ति',
        message: 'सामुदायिक मैदान गेट 2 पर शाम 6:00 बजे तक पीने के पानी के टैंकर और राशन किट उपलब्ध हैं।',
        source: 'राहत दल',
      ),
      'or': LocalizedContent(
        title: 'ବିଶୁଦ୍ଧ ପାନୀୟ ଜଳ ଓ ଖାଦ୍ୟ ଯୋଗାଣ',
        message: 'କମ୍ୟୁନିଟି ପଡ଼ିଆ ଗେଟ୍ ୨ ରେ ସନ୍ଧ୍ୟା ୬:୦୦ ପର୍ଯ୍ୟନ୍ତ ପାନୀୟ ଜଳ ଟ୍ୟାଙ୍କର ଏବଂ ରିଲିଫ୍ ରାସନ୍ କିଟ୍ ଉପଲବ୍ଧ।',
        source: 'ରିଲିଫ୍ ଟିମ୍',
      ),
      'bn': LocalizedContent(
        title: 'বিশুদ্ধ পানীয় জল ও খাদ্য সরবরাহ',
        message: 'কমিউনিটি গ্রাউন্ড গেট ২-এ সন্ধ্যা ৬:০০টা পর্যন্ত পানীয় জলের ট্যাঙ্কার এবং রেশন কিট পাওয়া যাচ্ছে।',
        source: 'ত্রাণ দল',
      ),
      'as': LocalizedContent(
        title: 'বিশুদ্ধ খোৱাপানী আৰু খাদ্য যোগান',
        message: 'কমিউনিটি গ্ৰাউণ্ড গেট ২-ত সন্ধিয়া ৬:০০ বজালৈকে খোৱাপানীৰ টেংকাৰ আৰু খাদ্যৰ কিট উপলব্ধ।',
        source: 'সাহায্য দল',
      ),
      'ml': LocalizedContent(
        title: 'കുടിവെള്ളവും ഭക്ഷണ വിതരണവും',
        message: 'കമ്മ്യൂണിറ്റി ഗ്രൗണ്ട് ഗേറ്റ് 2-ൽ വൈകുന്നേരം 6:00 മണി വരെ കുടിവെള്ള ടാങ്കറുകളും റേഷൻ കിറ്റുകളും ലഭ്യമാണ്.',
        source: 'റിലീഫ് ടീം',
      ),
      'gu': LocalizedContent(
        title: 'શુદ્ધ પીવાનું પાણી અને ખાદ્ય પુરવઠો',
        message: 'કમ્યુનિટી ગ્રાઉન્ડ ગેટ 2 પર સાંજે 6:00 વાગ્યા સુધી પીવાના પાણીના ટેન્કર અને રાશન કીટ ઉપલબ્ધ છે.',
        source: 'રાહત ટીમ',
      ),
      'mai': LocalizedContent(
        title: 'स्वच्छ जल आ भोजन आपूर्ति',
        message: 'कम्युनिटी ग्राउंड गेट 2 पर सांझ 6:00 बजे धरि पीबाक पानीक टैंकर आ राशन किट उपलब्ध अछि।',
        source: 'राहत दल',
      ),
      'brx': LocalizedContent(
        title: 'गोगो लोंनाय दै आरो आदार जगायनाय',
        message: 'कम्युनिटी ग्राउण्ड गेट 2 आव बेलासियानि 6:00 रिंगासिम लोंनाय दैनि टेंकार आरो जामुं किट मोननो हागोन।',
        source: 'मदाम हान्जा',
      ),
      'te': LocalizedContent(
        title: 'తాగునీరు మరియు ఆహార సరఫరా',
        message: 'కమ్యూనిటీ గ్రౌండ్స్ గేట్ 2 వద్ద సాయంత్రం 6:00 గంటల వరకు తాగునీటి ట్యాంకర్లు మరియు రేషన్ కిట్లు అందుబాటులో ఉన్నాయి.',
        source: 'సహాయక బృందం',
      ),
      'mr': LocalizedContent(
        title: 'स्वच्छ पाणी आणि अन्न पुरवठा',
        message: 'संध्याकाळी ६:०० वाजेपर्यंत कम्युनिटी ग्राउंड गेट २ वर पिण्याच्या पाण्याचे टँकर आणि रेशन किट उपलब्ध आहेत.',
        source: 'मदत पथक',
      ),
      'ta': LocalizedContent(
        title: 'குடிநீர் மற்றும் உணவு வழங்கல்',
        message: 'சமுதாய மைதானம் கேட் 2 இல் மாலை 6:00 மணி வரை குடிநீர் டேங்கர்கள் மற்றும் ரேஷன் பொருட்கள் கிடைக்கின்றன.',
        source: 'நிவாரண குழு',
      ),
      'kn': LocalizedContent(
        title: 'ಶುದ್ಧ ಕುಡಿಯುವ ನೀರು ಮತ್ತು ಆಹಾರ ಪೂರೈಕೆ',
        message: 'ಸಂಜೆ 6:00 ಗಂಟೆಯವರೆಗೆ ಕಮ್ಯುನಿಟಿ ಗ್ರೌಂಡ್ ಗೇಟ್ 2 ರಲ್ಲಿ ಕುಡಿಯುವ ನೀರಿನ ಟ್ಯಾಂಕರ್‌ಗಳು ಮತ್ತು ಪಡಿತರ ಕಿಟ್‌ಗಳು ಲಭ್ಯವಿದೆ.',
        source: 'ಪರಿಹಾರ ತಂಡ',
      ),
      'pa': LocalizedContent(
        title: 'ਸਾਫ਼ ਪੀਣ ਵਾਲਾ ਪਾਣੀ ਅਤੇ ਭੋਜਨ ਸਪਲਾਈ',
        message: 'ਕਮਿਊਨਿਟੀ ਗਰਾਊਂਡ ਗੇਟ 2 ਵਿਖੇ ਸ਼ਾਮ 6:00 ਵਜੇ ਤੱਕ ਪੀਣ ਵਾਲੇ ਪਾਣੀ ਦੇ ਟੈਂਕਰ ਅਤੇ ਰਾਸ਼ਨ ਕਿੱਟਾਂ ਉਪਲਬਧ ਹਨ।',
        source: 'ਰਾਹਤ ਟੀਮ',
      ),
      'ks': LocalizedContent(
        title: 'सफ़ा आब त गज़ा फराहम',
        message: 'कम्युनिटी ग्राउंड गेट २ प्यठ शामुक ६:०० बजे तान सफ़ा आब त राशन किट दस्तयाब छ।',
        source: 'राहत टीम',
      ),
    },
  };

  // ---------------------------------------------------------------------------
  // 2. Severity titles across 15 languages
  // ---------------------------------------------------------------------------
  static const Map<AnnouncementSeverity, Map<String, String>> severityTitles = {
    AnnouncementSeverity.evacuation: {
      'en': 'Evacuation Alert',
      'hi': 'निकासी चेतावनी',
      'or': 'ସ୍ଥାନାନ୍ତର ସତର୍କତା',
      'bn': 'উচ্ছেদ সতর্কতা',
      'as': 'স্থানান্তৰৰ সতৰ্কবাণী',
      'ml': 'ഒഴിപ്പിക്കൽ മുന്നറിയിപ്പ്',
      'gu': 'સ્થળાંતર ચેતવણી',
      'mai': 'निकासी चेतावनी',
      'brx': 'खारखारनाय सांग्रांथि',
      'te': 'ఖాళీ చేయు హెచ్చరిక',
      'mr': 'स्थलांतर इशारा',
      'ta': 'வெளியேற்ற எச்சரிக்கை',
      'kn': 'ಸ್ಥಳಾಂತರ ಎಚ್ಚರಿಕೆ',
      'pa': 'ਨਿਕਾਸੀ ਚੇਤਾਵਨੀ',
      'ks': 'निकासी चेतावनी',
    },
    AnnouncementSeverity.warning: {
      'en': 'Emergency Warning',
      'hi': 'आपातकालीन चेतावनी',
      'or': 'ଜରୁରୀକାଳୀନ ସତର୍କତା',
      'bn': 'জরুরি সতর্কতা',
      'as': 'জৰুৰীকালীন সতৰ্কবাণী',
      'ml': 'അടിയന്തര മുന്നറിയിപ്പ്',
      'gu': 'ઇમરજન્સી ચેતવણી',
      'mai': 'आपातकालीन चेतावनी',
      'brx': 'जायख्लं सांग्रांथि',
      'te': 'అత్యవసర హెచ్చరిక',
      'mr': 'आपत्कालीन चेतावणी',
      'ta': 'அவசர எச்சரிக்கை',
      'kn': 'ತುರ್ತು ಎಚ್ಚರಿಕೆ',
      'pa': 'ਐਮਰਜੈਂਸੀ ਚੇਤਾਵਨੀ',
      'ks': 'हंगामी ख़बरदार',
    },
    AnnouncementSeverity.advisory: {
      'en': 'Advisory Notice',
      'hi': 'परामर्श सूचना',
      'or': 'ପରାମର୍ଶ ସୂଚନା',
      'bn': 'পরামর্শ বিজ্ঞপ্তি',
      'as': 'পৰামৰ্শ জাননী',
      'ml': 'നിർദ്ദേശ അറിയിപ്പ്',
      'gu': 'માર્ગદર્શક સૂચના',
      'mai': 'परामर्श सूचना',
      'brx': 'खोंथा खौरां',
      'te': 'సలహా నోటీసు',
      'mr': 'सल्लागार सूचना',
      'ta': 'ஆலோசனை அறிவிப்பு',
      'kn': 'ಸಲಹಾ ಸೂಚನೆ',
      'pa': 'ਸਲਾਹਕਾਰ ਸੂਚਨਾ',
      'ks': 'मश्वरा सूचना',
    },
  };

  // ---------------------------------------------------------------------------
  // 3. Quick suggestions & mesh broadcast templates across 15 languages
  // ---------------------------------------------------------------------------
  static const List<Map<String, String>> messageTemplates = [
    // Safe shelter available at Sector 4 (b_init)
    {
      'en': 'Safe shelter available at Sector 4 Community Center with drinking water.',
      'hi': 'सेक्टर 4 सामुदायिक केंद्र में पीने के पानी के साथ सुरक्षित आश्रय उपलब्ध है।',
      'or': 'ସେକ୍ଟର ୪ କମ୍ୟୁନିଟି ସେଣ୍ଟରରେ ପାନୀୟ ଜଳ ସହିତ ନିରାପଦ ଆଶ୍ରୟସ୍ଥଳ ଉପଲବ୍ଧ।',
      'bn': 'সেক্টর ৪ কমিউনিটি সেন্টারে পানীয় জলসহ নিরাপদ আশ্রয় পাওয়া যাচ্ছে।',
      'as': 'ছেক্টৰ ৪ কমিউনিটি চেণ্টাৰত খোৱাপানীৰ সৈতে সুৰক্ষিত আশ্ৰয় উপলব্ধ।',
      'ml': 'സെക്ടർ 4 കമ്മ്യൂണിറ്റി സെന്ററിൽ കുടിവെള്ള സൗകര്യത്തോടെ സുരക്ഷിത അഭയകേന്ദ്രം ലഭ്യമാണ്.',
      'gu': 'સેક્ટર 4 કોમ્યુનિટી સેન્ટર ખાતે પીવાના પાણી સાથે સુરક્ષિત આશ્રય ઉપલબ્ધ છે.',
      'mai': 'सेक्टर 4 कम्युनिटी सेंटर मे पीबाक पानीक संग सुरक्षित आश्रय उपलब्ध अछि।',
      'brx': 'सेक्टर 4 कम्युनिटी सेन्टाराव लोंनाय दैनि थाफानाय रैखाथि बास्थि दं।',
      'te': 'సెక్టార్ 4 కమ్యూనిటీ సెంటర్‌లో తాగునీటి సదుపాయంతో సురక్షిత ఆశ్రయం అందుబాటులో ఉంది.',
      'mr': 'सेक्टर ४ कम्युनिटी सेंटरमध्ये पिण्याच्या पाण्यासह सुरक्षित निवारा उपलब्ध आहे.',
      'ta': 'செக்டார் 4 சமுதாய நலக்கூடத்தில் குடிநீருடன் கூடிய பாதுகாப்பான தங்குமிடம் உள்ளது.',
      'kn': 'ಸೆಕ್ಟರ್ 4 ಕಮ್ಯುನಿಟಿ ಸೆಂಟರ್‌ನಲ್ಲಿ ಕುಡಿಯುವ ನೀರಿನೊಂದಿಗೆ ಸುರಕ್ಷಿತ ಆಶ್ರಯ ಲಭ್ಯವಿದೆ.',
      'pa': 'ਸੈਕਟਰ 4 ਕਮਿਊਨਿਟੀ ਸੈਂਟਰ ਵਿਖੇ ਪੀਣ ਵਾਲੇ ਪਾਣੀ ਦੇ ਨਾਲ ਸੁਰੱਖਿਅਤ ਆਸਰਾ ਉਪਲਬਧ ਹੈ।',
      'ks': 'सेक्टर ४ कम्युनिटी सेंटर मंज़ सफ़ा आबस स्यत महफ़ूज़ जाय दस्तयाब छ।',
    },
    // Road blocked near Gate 2.
    {
      'en': 'Road blocked near Gate 2.',
      'hi': 'गेट 2 के पास सड़क अवरुद्ध है।',
      'or': 'ଗେଟ୍ ୨ ନିକଟରେ ରାସ୍ତା ଅବରୋଧ ଅଛି।',
      'bn': 'গেট ২ এর কাছে রাস্তা বন্ধ রয়েছে।',
      'as': 'গেট ২ ৰ কাষত পথ বন্ধ হৈ আছে।',
      'ml': 'ഗേറ്റ് 2 ന് സമീപം റോഡ് തടസ്സപ്പെട്ടിരിക്കുന്നു.',
      'gu': 'ગેટ 2 પાસે રસ્તો બ્લોક છે.',
      'mai': 'गेट 2 क लग सड़क जाम अछि।',
      'brx': 'गेट 2 नि खाथियाव लामाया हेंथा जादों।',
      'te': 'గేట్ 2 సమీపంలో రోడ్డు బ్లాక్ చేయబడింది.',
      'mr': 'गेट २ जवळ रस्ता बंद आहे.',
      'ta': 'கேட் 2 அருகே சாலை மூடப்பட்டுள்ளது.',
      'kn': 'ಗೇಟ್ 2 ಬಳಿ ರಸ್ತೆ ನಿರ್ಬಂಧಿಸಲಾಗಿದೆ.',
      'pa': 'ਗੇਟ 2 ਦੇ ਨੇੜੇ ਸੜਕ ਬੰਦ ਹੈ।',
      'ks': 'गेट २ क्य नज़दीक वत बंद छ।',
    },
    // Safe shelter available.
    {
      'en': 'Safe shelter available.',
      'hi': 'सुरक्षित आश्रय उपलब्ध है।',
      'or': 'ନିରାପଦ ଆଶ୍ରୟସ୍ଥଳ ଉପଲବ୍ଧ।',
      'bn': 'নিরাপদ আশ্রয় পাওয়া যাচ্ছে।',
      'as': 'সুৰক্ষিত আশ্ৰয় উপলব্ধ।',
      'ml': 'സുരക്ഷിത അഭയകേന്ദ്രം ലഭ്യമാണ്.',
      'gu': 'સુરક્ષિત આશ્રય ઉપલબ્ધ છે.',
      'mai': 'सुरक्षित आश्रय उपलब्ध अछि।',
      'brx': 'रैखाथि बास्थि मोननो हागोन।',
      'te': 'సురక్షిత ఆశ్రయం అందుబాటులో ఉంది.',
      'mr': 'सुरक्षित निवारा उपलब्ध आहे.',
      'ta': 'பாதுகாப்பான தங்குமிடம் உள்ளது.',
      'kn': 'ಸುರಕ್ಷಿತ ಆಶ್ರಯ ಲಭ್ಯವಿದೆ.',
      'pa': 'ਸੁਰੱਖਿਅਤ ਆਸਰਾ ਉਪਲਬਧ ਹੈ।',
      'ks': 'महफ़ूज़ पनाहगाह दस्तयाब छ।',
    },
    // Do not use this route.
    {
      'en': 'Do not use this route.',
      'hi': 'इस मार्ग का उपयोग न करें।',
      'or': 'ଏହି ରାସ୍ତା ବ୍ୟବହାର କରନ୍ତୁ ନାହିଁ।',
      'bn': 'এই রুটটি ব্যবহার করবেন না।',
      'as': 'এই পথ ব্যৱহাৰ নকৰিব।',
      'ml': 'ഈ റൂട്ട് ഉപയോഗിക്കരുത്.',
      'gu': 'આ માર્ગનો ઉપયોગ કરશો નહીં.',
      'mai': 'एहि रस्ताक उपयोग नहि करू।',
      'brx': 'बे लामाखौ बाहायनाङा।',
      'te': 'ఈ మార్గాన్ని ఉపయోగించవద్దు.',
      'mr': 'या मार्गाचा वापर करू नका.',
      'ta': 'இந்த வழியைப் பயன்படுத்த வேண்டாம்.',
      'kn': 'ಈ ಮಾರ್ಗವನ್ನು ಬಳಸಬೇಡಿ.',
      'pa': 'ਇਸ ਰਸਤੇ ਦੀ ਵਰਤੋਂ ਨਾ ਕਰੋ।',
      'ks': 'यह वत म्य बरतिव।',
    },
    // Drinking water point active at Relief Tent 3.
    {
      'en': 'Drinking water point active at Relief Tent 3.',
      'hi': 'राहत तंबू 3 पर पीने के पानी का बिंदु सक्रिय है।',
      'or': 'ରିଲିଫ୍ ତମ୍ବୁ ୩ ରେ ପାନୀୟ ଜଳ କେନ୍ଦ୍ର ସକ୍ରିୟ ଅଛି।',
      'bn': 'ত্রাণ তাঁবু ৩ এ পানীয় জলের পয়েন্ট চালু রয়েছে।',
      'as': 'সাহায্য তম্বু ৩ ত খোৱাপানীৰ ব্যৱস্থা সক্ৰিয় আছে।',
      'ml': 'റിലീഫ് ടെന്റ് 3 ൽ കുടിവെള്ള പോയിന്റ് പ്രവർത്തിക്കുന്നു.',
      'gu': 'રાહત તંબુ 3 ખાતે પીવાના પાણીનો પોઇન્ટ કાર્યરત છે.',
      'mai': 'राहत तंबू 3 पर पीबाक पानीक केंद्र चालू अछि।',
      'brx': 'राहत ताम्बु 3 आव लोंनाय दैनि जायगाया साख्रिथाव।',
      'te': 'రిలీఫ్ టెంట్ 3 వద్ద తాగునీటి కేంద్రం అందుబాటులో ఉంది.',
      'mr': 'मदत तंबू ३ येथे पिण्याच्या पाण्याचा बिंदू सुरू आहे.',
      'ta': 'நிவாரண கூடாரம் 3 இல் குடிநீர் விநியோகம் செயல்படுகிறது.',
      'kn': 'ಪರಿಹಾರ ಟೆಂಟ್ 3 ರಲ್ಲಿ ಕುಡಿಯುವ ನೀರಿನ ಪಾಯಿಂಟ್ ಸಕ್ರಿಯವಾಗಿದೆ.',
      'pa': 'ਰਾਹਤ ਟੈਂਟ 3 ਵਿਖੇ ਪੀਣ ਵਾਲੇ ਪਾਣੀ ਦਾ ਪੁਆਇੰਟ ਸਰਗਰਮ ਹੈ।',
      'ks': 'राहत तंबू ३ मंज़ सफ़ा आबक पॉइंट चालू छ।',
    },
  ];

  // ---------------------------------------------------------------------------
  // 4. SOS Distress Signal Templates across 15 languages
  // ---------------------------------------------------------------------------
  static const Map<String, String> sosTemplates = {
    'en': 'EMERGENCY DISTRESS SIGNAL: Assistance needed at current location ({coords}).',
    'hi': 'आपातकालीन संकट संकेत: वर्तमान स्थान ({coords}) पर सहायता की आवश्यकता है।',
    'or': 'ଜରୁରୀକାଳୀନ ବିପଦ ସଙ୍କେତ: ବର୍ତ୍ତମାନର ସ୍ଥାନରେ ({coords}) ସହାୟତା ଆବଶ୍ୟକ।',
    'bn': 'জরুরি বিপদ সংকেত: বর্তমান অবস্থানে ({coords}) সাহায্যের প্রয়োজন।',
    'as': 'জৰুৰীকালীন বিপদৰ সংকেত: বৰ্তমান স্থানত ({coords}) সহায়ৰ প্ৰয়োজন।',
    'ml': 'അടിയന്തര ദുരിത സിഗ്നൽ: നിലവിലെ ലൊക്കേഷനിൽ ({coords}) സഹായം ആവശ്യമാണ്.',
    'gu': 'ઇમરજન્સી સંકટ સંકેત: વર્તમાન સ્થાન ({coords}) પર તાત્કાલિક સહાયની જરૂર છે.',
    'mai': 'आपातकालीन संकट संकेत: वर्तमान स्थान ({coords}) पर सहायताक आवश्यकता अछि।',
    'brx': 'जायख्लं खौरां संखेथ: आथिखालनि जायगायाव ({coords}) हेफाजाब नांगौ।',
    'te': 'అత్యవసర విపత్తు సంకేతం: ప్రస్తుత ప్రదేశంలో ({coords}) సహాయం అవసరం.',
    'mr': 'आपत्कालीन संकट संदेश: सद्यस्थितीत ({coords}) येथे मदतीची आवश्यकता आहे.',
    'ta': 'அவசர ஆபத்து சமிக்ஞை: தற்போதைய இடத்தில் ({coords}) உடனடி உதவி தேவைப்படுகிறது.',
    'kn': 'ತುರ್ತು ಅಪಾಯದ ಸಂಕೇತ: ಪ್ರಸ್ತುತ ಸ್ಥಳದಲ್ಲಿ ({coords}) ಸಹಾಯದ ಅಗತ್ಯವಿದೆ.',
    'pa': 'ਐਮਰਜੈਂਸੀ ਸੰਕਟ ਸੰਕੇਤ: ਮੌਜੂਦਾ ਸਥਾਨ ({coords}) ਤੇ ਮਦਦ ਦੀ ਲੋੜ ਹੈ।',
    'ks': 'हंगामी मुसीबत निशानी: आथ्युक जायस ({coords}) प्यठ मद्दच ज़रूरत छ।',
  };

  /// Returns translated SOS content for all 15 languages given coordinates.
  static Map<String, String> getSosTranslations(String coords) {
    return sosTemplates.map(
      (lang, template) => MapEntry(lang, template.replaceAll('{coords}', coords)),
    );
  }

  /// Looks up translations for a given message content if it matches any template.
  static Map<String, String>? findTemplateTranslations(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    for (final template in messageTemplates) {
      if (template.values.any((val) => val.trim().toLowerCase() == trimmed.toLowerCase())) {
        return template;
      }
    }
    return null;
  }

  /// Builds a full 15-language translations map for a newly composed announcement.
  /// If the body matches a known template, the body is fully translated.
  /// If custom, it preserves the custom text and provides translated titles.
  static Map<String, LocalizedContent> getTranslationsForComposed({
    required String title,
    required String message,
    required AnnouncementSeverity severity,
    required String source,
  }) {
    final titleByLang = severityTitles[severity] ?? {};
    final bodyTranslations = findTemplateTranslations(message);

    final Map<String, LocalizedContent> result = {};
    const allLangs = ['en', 'hi', 'or', 'bn', 'as', 'ml', 'gu', 'mai', 'brx', 'te', 'mr', 'ta', 'kn', 'pa', 'ks'];

    for (final lang in allLangs) {
      result[lang] = LocalizedContent(
        title: titleByLang[lang] ?? title,
        message: bodyTranslations?[lang] ?? message,
        source: source,
      );
    }

    return result;
  }

  /// Returns translations map for quick suggestion chips in a specific language.
  static List<String> getSuggestionsForLanguage(String langCode) {
    return [
      messageTemplates[1][langCode] ?? messageTemplates[1]['en']!,
      messageTemplates[2][langCode] ?? messageTemplates[2]['en']!,
      messageTemplates[3][langCode] ?? messageTemplates[3]['en']!,
      messageTemplates[4][langCode] ?? messageTemplates[4]['en']!,
    ];
  }

  /// Helper to resolve content of a message with graceful fallback.
  static String resolveMessageContent(
    String content,
    String langCode, {
    Map<String, String>? translations,
  }) {
    if (translations != null && translations[langCode] != null && translations[langCode]!.isNotEmpty) {
      return translations[langCode]!;
    }
    final template = findTemplateTranslations(content);
    if (template != null && template[langCode] != null && template[langCode]!.isNotEmpty) {
      return template[langCode]!;
    }
    return content;
  }
}
