const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

// Initialize the Gemini SDK
// Note: Ensure the GEMINI_API_KEY is available in the environment variables (e.g., via .env file or Firebase Secret Manager)
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.processFoodImage = onDocumentCreated("image_processing_queue/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        console.log("No data associated with the event");
        return;
    }

    const data = snap.data();
    const { userId, imageUrl, storagePath } = data;

    if (!storagePath) {
        console.error("No storage path provided in the document");
        return;
    }

    try {
        console.log(`Processing image for user: ${userId}, path: ${storagePath}`);

        // 1. Download image from Firebase Storage
        const bucket = admin.storage().bucket();
        const file = bucket.file(storagePath);
        const [buffer] = await file.download();

        const base64Image = buffer.toString('base64');

        // 2. Call Gemini API for identification, OCR, and storage suggestions
        const prompt = "Analyze this image. Identify the main food item shown. Also, carefully read any text to find an expiry date or best before date. Finally, provide a brief suggestion on how best to store this item to keep it fresh. Return the result strictly as a JSON object with three keys: 'foodName' (string, a clear short name of the food), 'expiryDate' (string, the date found, or null if none found), and 'storageSuggestion' (string, short advice on how to store it). Do not include markdown formatting or extra text.";

        const model = genAI.getGenerativeModel({
            model: "gemini-1.5-flash",
            generationConfig: {
                responseMimeType: "application/json",
            }
        });

        const imagePart = {
            inlineData: {
                data: base64Image,
                mimeType: "image/jpeg"
            }
        };

        const response = await model.generateContent([prompt, imagePart]);
        const resultText = response.response.text();
        console.log("Gemini Response:", resultText);

        let parsedResult;
        try {
            parsedResult = JSON.parse(resultText);
        } catch (e) {
            console.error("Failed to parse Gemini response as JSON", e);
            // Fallback parsing if JSON parsing fails (e.g., if Gemini still wraps in markdown)
            const cleanText = resultText.replace(/```json/g, '').replace(/```/g, '').trim();
            parsedResult = JSON.parse(cleanText);
        }

        const foodName = parsedResult.foodName || 'Unknown Food';
        const expiryDate = parsedResult.expiryDate || 'Unknown Expiry';
        const storageSuggestion = parsedResult.storageSuggestion || 'Store in a cool, dry place.';

        // 3. Update the queue document with the results and status 'completed'
        await snap.ref.update({
            foodName: foodName,
            expiryDate: expiryDate,
            storageSuggestion: storageSuggestion,
            status: 'completed',
            processedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`Successfully processed queue document ${event.params.docId}`);

    } catch (error) {
        console.error("Error processing food image:", error);

        // Optionally update the queue document to indicate failure
        await snap.ref.update({
            status: 'error',
            errorMessage: error.message
        });
    }
});
