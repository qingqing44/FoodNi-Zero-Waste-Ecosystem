import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Seeds the Firestore [recipes] collection with a curated set of default
/// recipes on first launch.
///
/// Design goals:
/// - **Idempotent**: checks for existing documents before writing anything.
/// - **Fast**: uses a single [WriteBatch] (max 500 ops; our seed is ~20).
/// - **Non-blocking**: failures are caught and logged; the app always starts.
/// - **Debug helper**: [reseedRecipes] deletes + reinserts all recipes.
///   It must never be called automatically in production.
class RecipeSeeder {
  RecipeSeeder._();

  static const _collection = 'recipes';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks whether the [recipes] collection already has documents.
  /// If it is empty, inserts the full default recipe list via a [WriteBatch].
  ///
  /// Safe to call on every app start — exits immediately when recipes exist.
  static Future<void> seedRecipesIfNeeded() async {
    try {
      final col = FirebaseFirestore.instance.collection(_collection);

      // Use limit(1) to avoid a full collection scan.
      final existing = await col.limit(1).get();
      if (existing.docs.isNotEmpty) {
        debugPrint('[RecipeSeeder] Collection already seeded — skipping.');
        return;
      }

      await _insertAll(col);
      debugPrint(
        '[RecipeSeeder] Seeded ${_defaultRecipes.length} recipes successfully.',
      );
    } catch (e, stack) {
      // Seeding failure must never crash the app.
      debugPrint('[RecipeSeeder] Seeding failed: $e\n$stack');
    }
  }

  /// **Debug only** — deletes every document in [recipes] and reinserts
  /// the default set from scratch.
  ///
  /// Call this manually from a debug menu / flutter test; never call it
  /// automatically. In release builds, prefer to leave [recipes] as-is.
  static Future<void> reseedRecipes() async {
    assert(
      () {
        return true; // assertion passes only in debug mode
      }(),
      'reseedRecipes() must not be called in production.',
    );

    try {
      final col = FirebaseFirestore.instance.collection(_collection);

      // Delete all existing documents in batches of 500.
      QuerySnapshot snapshot;
      do {
        snapshot = await col.limit(500).get();
        if (snapshot.docs.isEmpty) break;

        final deleteBatch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
      } while (snapshot.docs.length == 500);

      await _insertAll(col);
      debugPrint(
        '[RecipeSeeder] Re-seeded ${_defaultRecipes.length} recipes.',
      );
    } catch (e, stack) {
      debugPrint('[RecipeSeeder] Reseed failed: $e\n$stack');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Writes [_defaultRecipes] to [col] using a single [WriteBatch].
  static Future<void> _insertAll(CollectionReference col) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final recipe in _defaultRecipes) {
      // Let Firestore auto-generate document IDs.
      batch.set(col.doc(), recipe);
    }
    await batch.commit();
  }

  // ── Default recipes ────────────────────────────────────────────────────────
  //
  // 20 recipes covering: breakfast, lunch, dinner, snacks, vegetarian.
  // All ingredient names are lower-case to match the normalised inventory keys.

  static const List<Map<String, dynamic>> _defaultRecipes = [
    // ── BREAKFAST ─────────────────────────────────────────────────────────────
    {
      'title': 'Tomato Omelette',
      'imageUrl':
          'https://images.unsplash.com/photo-1510693206972-df098062cb71?auto=format&fit=crop&q=80&w=800',
      'ingredients': ['egg', 'tomato', 'onion', 'salt', 'pepper', 'butter'],
      'instructions': [
        'Crack 3 eggs into a bowl and whisk with salt and pepper.',
        'Dice the tomato and onion into small cubes.',
        'Melt butter in a non-stick pan over medium heat.',
        'Pour in the egg mixture and let it set for 30 seconds.',
        'Scatter the tomato and onion over one half.',
        'Fold the omelette over and cook for another minute.',
        'Slide onto a plate and serve immediately.',
      ],
      'preparationTime': 10,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Shakshuka',
      'imageUrl':
          'https://images.unsplash.com/photo-1590412200988-a436970781fa?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'egg',
        'tomato',
        'onion',
        'garlic',
        'bell pepper',
        'cumin',
        'paprika',
        'olive oil',
        'salt',
      ],
      'instructions': [
        'Heat olive oil in a large skillet over medium heat.',
        'Sauté diced onion and bell pepper until softened, about 5 minutes.',
        'Add minced garlic, cumin, and paprika; cook for 1 minute.',
        'Pour in crushed tomatoes, season with salt, and simmer for 10 minutes.',
        'Make wells in the sauce and crack eggs directly into them.',
        'Cover and cook until whites are set but yolks are still runny, 5–7 min.',
        'Serve straight from the pan with crusty bread.',
      ],
      'preparationTime': 25,
      'difficulty': 'Medium',
      'source': 'firebase',
    },
    {
      'title': 'French Toast',
      'imageUrl':
          'https://images.unsplash.com/photo-1484723091739-30990ddc1f6f?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'bread',
        'egg',
        'milk',
        'butter',
        'sugar',
        'cinnamon',
        'vanilla extract',
      ],
      'instructions': [
        'Whisk together eggs, milk, sugar, cinnamon, and vanilla in a shallow bowl.',
        'Dip bread slices into the egg mixture, coating both sides well.',
        'Melt butter in a pan over medium heat.',
        'Cook each slice for 2–3 minutes per side until golden brown.',
        'Serve with maple syrup or powdered sugar.',
      ],
      'preparationTime': 15,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Pancakes',
      'imageUrl':
          'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'flour',
        'egg',
        'milk',
        'butter',
        'baking powder',
        'sugar',
        'salt',
      ],
      'instructions': [
        'Whisk together flour, baking powder, sugar, and salt in a bowl.',
        'In another bowl, beat the egg with milk and melted butter.',
        'Pour the wet ingredients into the dry and mix until just combined.',
        'Heat a lightly buttered griddle over medium heat.',
        'Pour ¼ cup batter per pancake; cook until bubbles form, then flip.',
        'Cook the other side until golden. Serve with butter and syrup.',
      ],
      'preparationTime': 20,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Scrambled Eggs on Toast',
      'imageUrl':
          'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&q=80&w=800',
      'ingredients': ['egg', 'bread', 'butter', 'milk', 'salt', 'pepper'],
      'instructions': [
        'Toast two slices of bread to your liking.',
        'Crack 3 eggs into a bowl with a splash of milk, salt, and pepper; whisk.',
        'Melt butter in a non-stick pan over low-medium heat.',
        'Add the eggs; stir gently and continuously with a spatula.',
        'Remove from heat just before they look fully set — residual heat finishes them.',
        'Pile the scrambled eggs onto toast and serve.',
      ],
      'preparationTime': 8,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Mushroom Omelette',
      'imageUrl':
          'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'egg',
        'mushroom',
        'onion',
        'butter',
        'cheese',
        'salt',
        'pepper',
      ],
      'instructions': [
        'Slice mushrooms and dice onion.',
        'Sauté mushrooms and onion in butter over medium heat until tender.',
        'Whisk 3 eggs with salt and pepper.',
        'Pour eggs into the pan around the mushroom mixture.',
        'Add shredded cheese on one half.',
        'Fold the omelette and cook for 1 more minute.',
        'Serve immediately.',
      ],
      'preparationTime': 12,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Banana Smoothie',
      'imageUrl':
          'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&q=80&w=800',
      'ingredients': ['banana', 'milk', 'yogurt', 'honey', 'ice'],
      'instructions': [
        'Peel and slice the banana.',
        'Add banana, milk, yogurt, honey, and ice to a blender.',
        'Blend on high speed for 30–45 seconds until smooth.',
        'Taste and adjust sweetness with more honey if desired.',
        'Pour into a glass and serve immediately.',
      ],
      'preparationTime': 5,
      'difficulty': 'Easy',
      'source': 'firebase',
    },

    // ── LUNCH ─────────────────────────────────────────────────────────────────
    {
      'title': 'Grilled Cheese Sandwich',
      'imageUrl':
          'https://images.unsplash.com/photo-1528736235302-52922df5c122?auto=format&fit=crop&q=80&w=800',
      'ingredients': ['bread', 'cheese', 'butter'],
      'instructions': [
        'Butter one side of each bread slice generously.',
        'Place one slice butter-side down in a cold pan.',
        'Layer cheese slices on the bread.',
        'Top with the second slice, butter-side up.',
        'Cook over medium-low heat for 3–4 minutes until golden.',
        'Flip carefully and cook the other side for 3 minutes.',
        'Slice diagonally and serve hot.',
      ],
      'preparationTime': 10,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Tuna Sandwich',
      'imageUrl':
          'https://images.unsplash.com/photo-1553909489-cd47e0907980?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'bread',
        'tuna',
        'mayonnaise',
        'onion',
        'celery',
        'lemon',
        'salt',
        'pepper',
      ],
      'instructions': [
        'Drain the canned tuna well.',
        'Mix tuna with diced onion, celery, mayonnaise, and a squeeze of lemon.',
        'Season with salt and pepper.',
        'Spread the mixture generously on a slice of bread.',
        'Top with another slice or serve open-faced.',
        'Optionally add lettuce or tomato slices.',
      ],
      'preparationTime': 10,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Chicken Salad',
      'imageUrl':
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'chicken',
        'lettuce',
        'tomato',
        'cucumber',
        'onion',
        'olive oil',
        'lemon',
        'salt',
        'pepper',
      ],
      'instructions': [
        'Season chicken breast with salt and pepper; grill or pan-fry until cooked through.',
        'Let the chicken rest for 5 minutes, then slice or shred.',
        'Tear lettuce into bite-sized pieces and place in a large bowl.',
        'Dice tomato, cucumber, and onion; add to the bowl.',
        'Top with the chicken.',
        'Drizzle with olive oil and a squeeze of lemon. Toss and serve.',
      ],
      'preparationTime': 20,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Veggie Wrap',
      'imageUrl':
          'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'tortilla',
        'lettuce',
        'tomato',
        'cucumber',
        'carrot',
        'cheese',
        'hummus',
        'salt',
        'pepper',
      ],
      'instructions': [
        'Warm the tortilla in a dry pan or microwave for 20 seconds.',
        'Spread hummus over the centre of the tortilla.',
        'Layer shredded lettuce, sliced tomato, cucumber ribbons, and grated carrot.',
        'Sprinkle with cheese, salt, and pepper.',
        'Fold the sides in and roll tightly from the bottom.',
        'Slice in half and serve.',
      ],
      'preparationTime': 10,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Vegetable Soup',
      'imageUrl':
          'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'carrot',
        'potato',
        'onion',
        'garlic',
        'celery',
        'tomato',
        'vegetable broth',
        'olive oil',
        'salt',
        'pepper',
        'parsley',
      ],
      'instructions': [
        'Heat olive oil in a large pot over medium heat.',
        'Sauté diced onion and garlic until translucent.',
        'Add diced carrots, potato, and celery; stir for 3 minutes.',
        'Pour in vegetable broth and bring to a boil.',
        'Add diced tomatoes and season with salt and pepper.',
        'Reduce heat and simmer for 20 minutes until vegetables are tender.',
        'Stir in chopped parsley and serve.',
      ],
      'preparationTime': 35,
      'difficulty': 'Easy',
      'source': 'firebase',
    },

    // ── DINNER ────────────────────────────────────────────────────────────────
    {
      'title': 'Egg Fried Rice',
      'imageUrl':
          'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'rice',
        'egg',
        'onion',
        'garlic',
        'soy sauce',
        'vegetable oil',
        'salt',
        'pepper',
        'spring onion',
      ],
      'instructions': [
        'Cook rice and leave it to cool completely (day-old rice works best).',
        'Heat oil in a wok or large pan over high heat.',
        'Add diced onion and garlic; stir-fry for 1 minute.',
        'Push ingredients to the side, crack in the eggs and scramble.',
        'Add the cold rice and break up any clumps.',
        'Drizzle soy sauce over the rice and toss everything together.',
        'Season with salt and pepper; garnish with spring onion.',
      ],
      'preparationTime': 20,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Tomato Pasta',
      'imageUrl':
          'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'pasta',
        'tomato',
        'garlic',
        'onion',
        'olive oil',
        'basil',
        'salt',
        'pepper',
        'parmesan',
      ],
      'instructions': [
        'Cook pasta according to packet instructions; reserve ½ cup pasta water.',
        'Heat olive oil in a pan over medium heat.',
        'Sauté diced onion until soft, then add minced garlic for 1 minute.',
        'Add crushed tomatoes and simmer for 15 minutes.',
        'Season with salt, pepper, and fresh basil.',
        'Toss cooked pasta in the sauce, adding pasta water to loosen if needed.',
        'Serve topped with grated parmesan.',
      ],
      'preparationTime': 25,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Vegetable Stir Fry',
      'imageUrl':
          'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'broccoli',
        'carrot',
        'bell pepper',
        'onion',
        'garlic',
        'soy sauce',
        'sesame oil',
        'ginger',
        'vegetable oil',
      ],
      'instructions': [
        'Chop all vegetables into bite-sized pieces.',
        'Mix soy sauce, sesame oil, and grated ginger to make a quick sauce.',
        'Heat vegetable oil in a wok over high heat.',
        'Add onion and garlic; stir-fry for 1 minute.',
        'Add harder vegetables first (carrot, broccoli) and cook for 3 minutes.',
        'Add bell pepper and pour the sauce over everything.',
        'Toss constantly for 2 more minutes and serve over rice.',
      ],
      'preparationTime': 20,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Chicken Fried Rice',
      'imageUrl':
          'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'rice',
        'chicken',
        'egg',
        'onion',
        'garlic',
        'soy sauce',
        'sesame oil',
        'vegetable oil',
        'spring onion',
        'salt',
        'pepper',
      ],
      'instructions': [
        'Dice chicken breast and season with salt and pepper.',
        'Cook rice and allow it to cool.',
        'Stir-fry chicken in oil over high heat until golden; set aside.',
        'In the same pan, sauté onion and garlic for 1 minute.',
        'Scramble eggs in the pan.',
        'Add cold rice and stir-fry for 2 minutes.',
        'Return chicken, add soy sauce and sesame oil; toss well.',
        'Garnish with spring onion and serve.',
      ],
      'preparationTime': 25,
      'difficulty': 'Medium',
      'source': 'firebase',
    },
    {
      'title': 'Garlic Butter Pasta',
      'imageUrl':
          'https://images.unsplash.com/photo-1473093226795-af9932fe5856?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'pasta',
        'butter',
        'garlic',
        'parsley',
        'parmesan',
        'salt',
        'pepper',
        'olive oil',
      ],
      'instructions': [
        'Cook pasta until al dente; reserve 1 cup of pasta water.',
        'Melt butter with olive oil in a wide pan over low heat.',
        'Add minced garlic and cook gently for 2 minutes — do not brown.',
        'Toss the drained pasta into the butter-garlic mixture.',
        'Add pasta water gradually to create a silky sauce.',
        'Stir in chopped parsley and grated parmesan.',
        'Season generously with salt and pepper; serve immediately.',
      ],
      'preparationTime': 20,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Mashed Potato Bowl',
      'imageUrl':
          'https://images.unsplash.com/photo-1574894709920-11b28e7367e3?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'potato',
        'butter',
        'milk',
        'garlic',
        'salt',
        'pepper',
        'cheese',
        'spring onion',
      ],
      'instructions': [
        'Peel and cube potatoes; boil in salted water for 15 minutes until tender.',
        'Drain and return potatoes to the pot; allow steam to escape for 1 minute.',
        'Mash with butter and warm milk until smooth and fluffy.',
        'Stir in minced garlic, salt, and pepper.',
        'Top with shredded cheese and sliced spring onion.',
        'Serve as a main bowl or as a side.',
      ],
      'preparationTime': 25,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
    {
      'title': 'Baked Potatoes',
      'imageUrl':
          'https://images.unsplash.com/photo-1508313880080-c4bef0730395?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'potato',
        'olive oil',
        'salt',
        'butter',
        'sour cream',
        'cheese',
        'spring onion',
      ],
      'instructions': [
        'Preheat oven to 200°C (400°F).',
        'Scrub potatoes and pat dry. Pierce all over with a fork.',
        'Rub with olive oil and season generously with salt.',
        'Place directly on the oven rack and bake for 50–60 minutes.',
        'Check doneness by squeezing — it should give easily.',
        'Slice open and fluff the inside with a fork.',
        'Top with butter, sour cream, shredded cheese, and spring onion.',
      ],
      'preparationTime': 65,
      'difficulty': 'Easy',
      'source': 'firebase',
    },

    // ── SNACKS / VEGETARIAN ───────────────────────────────────────────────────
    {
      'title': 'Caprese Salad',
      'imageUrl':
          'https://images.unsplash.com/photo-1592417817098-8fd3d9eb14a5?auto=format&fit=crop&q=80&w=800',
      'ingredients': [
        'tomato',
        'mozzarella',
        'basil',
        'olive oil',
        'balsamic vinegar',
        'salt',
        'pepper',
      ],
      'instructions': [
        'Slice tomatoes and mozzarella into even rounds.',
        'Alternate tomato and mozzarella slices on a serving plate.',
        'Tuck fresh basil leaves between the slices.',
        'Drizzle generously with olive oil and balsamic vinegar.',
        'Season with flaky salt and cracked black pepper.',
        'Serve immediately at room temperature.',
      ],
      'preparationTime': 10,
      'difficulty': 'Easy',
      'source': 'firebase',
    },
  ];
}
