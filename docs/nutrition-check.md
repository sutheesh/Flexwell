# Nutrition check: nutrition.json against USDA FoodData Central

## Applied (27 Sep 2026)

- **Recipe weights are raw for meat, fish and eggs.** Chicken breast and thigh, sirloin, beef mince, tuna, turkey breast and prawns
  held cooked values; they now hold USDA raw values, like the other meats and fish already did.
- **Glass noodles are counted dry**, like the other noodles: the one recipe using them went from 210 g cooked to 50 g dry.
- **Every *Wrong* and *Check* value below was replaced with its USDA value.** The table shows the values *before* the fix.
- Every recipe's stated calories and macros were recalculated from its ingredients.
- Each ingredient in `nutrition.json` now has a `source` naming its USDA FDC ID or other source; a test keeps it that way.


Checked 27 Sep 2026. Each of the 171 ingredients in `Packages/FlexFitEngine/Sources/FlexFitEngine/Resources/nutrition.json` was matched to one USDA FoodData Central food in the state recipes use (raw, cooked, canned or dry), then compared per 100 g.

Sources (public domain): SR Legacy (April 2018), Foundation Foods (April 2026) and FNDDS 2021–2023 (for prepared dishes). Items USDA doesn't list are marked *Other source* and were checked for internal consistency (protein × 4 + carbs × 4 + fat × 9 ≈ calories).

**Status:** *OK* — calories within 10% (or 15 kcal) and every macro within 15% (or 2 g). *Check* — calories fine, a macro differs. *Wrong* — calories off. Values are kcal / protein / carbs / fat per 100 g.

**Summary:** 131 OK, 9 check, 13 wrong, 18 other source.

| Ingredient | Ours | USDA | USDA food (FDC ID) | Status |
|---|---|---|---|---|
| Beef mince | 250 / 26 / 0 / 17 | 215 / 18.6 / 0 / 15 | Beef, ground, 85% lean meat / 15% fat, raw (Includes foods for USDA's Food Distribution Program) (171796, SR) — counted cooked here | Wrong |
| Chicken breast | 165 / 31 / 0 / 3.6 | 120 / 22.5 / 0 / 2.6 | Chicken, broiler or fryers, breast, skinless, boneless, meat only, raw (171077, SR) — counted cooked here | Wrong |
| Chicken thigh | 209 / 26 / 0 / 11 | 121 / 19.7 / 0 / 4.1 | Chicken, broilers or fryers, dark meat, thigh, meat only, raw (173627, SR) — counted cooked here | Wrong |
| Dosa | 168 / 4 / 30 / 3.7 | 210 / 5.7 / 37 / 4 | Dosa, plain (2708347, FNDDS) | Wrong |
| Glass noodles | 84 / 0.1 / 21 / 0 | 351 / 0.2 / 86.1 / 0.1 | Noodles, chinese, cellophane or long rice (mung beans), dehydrated (174258, SR) — counted cooked here | Wrong |
| Hummus | 166 / 7.9 / 14 / 9.6 | 237 / 7.8 / 15 / 17.8 | Hummus, commercial (174289, SR) | Wrong |
| Peanut sauce | 400 / 12 / 20 / 30 | 257 / 6.3 / 22 / 16 | Peanut sauce (2707546, FNDDS) | Wrong |
| Protein bar | 370 / 33 / 37 / 12 | 412 / 30.3 / 38.4 / 15.2 | Nutrition bar (South Beach Living High Protein Bar) (2708124, FNDDS) | Wrong |
| Sambar | 60 / 3 / 9 / 1.5 | 86 / 4.3 / 11.8 / 2.7 | Sambar, vegetable stew (2707430, FNDDS) | Wrong |
| Sirloin | 206 / 26 / 0 / 11 | 131 / 22.1 / 0 / 4.1 | Beef, top sirloin, steak, separable lean only, trimmed to 1/8" fat, all grades, raw (174055, SR) — counted cooked here | Wrong |
| Tuna | 132 / 28 / 0 / 1.3 | 109 / 24.4 / 0 / 0.5 | Fish, tuna, fresh, yellowfin, raw (175159, SR) — counted cooked here | Wrong |
| Turkey breast | 135 / 30 / 0 / 1 | 114 / 23.7 / 0.1 / 1.5 | Turkey, whole, breast, meat only, raw (171098, SR) — counted cooked here | Wrong |
| Whey | 400 / 80 / 8 / 6 | 352 / 78.1 / 6.2 / 1.6 | Beverages, Protein powder whey based (173180, SR) | Wrong |
| Crackers | 430 / 9 / 70 / 12 | 418 / 9.5 / 74 / 8.6 | Crackers, saltines (includes oyster, soda, soup) (172746, SR) | Check |
| Granola | 471 / 10 / 64 / 20 | 489 / 13.7 / 53.9 / 24.3 | Cereals ready-to-eat, granola, homemade (171646, SR) | Check |
| Idli | 130 / 4 / 27 / 0.4 | 128 / 6.4 / 25 / 0.3 | Idli (2708346, FNDDS) | Check |
| Kale | 49 / 4.3 / 9 / 0.9 | 35 / 2.9 / 4.4 / 1.5 | Kale, raw (168421, SR) | Check |
| Parmesan | 431 / 38 / 4 / 29 | 392 / 35.8 / 3.2 / 25 | Cheese, parmesan, hard (170848, SR) | Check |
| Prawns | 99 / 24 / 0.2 / 0.3 | 85 / 20.1 / 0 / 0.5 | Crustaceans, shrimp, raw (175179, SR) — counted cooked here | Check |
| Rolled oats | 389 / 17 / 66 / 6.9 | 379 / 13.2 / 67.7 / 6.5 | Cereals, oats, regular and quick, not fortified, dry (173904, SR) | Check |
| Roti | 297 / 9.6 / 56 / 3.7 | 297 / 11.2 / 46.4 / 7.5 | Bread, chapati or roti, plain, commercially prepared (171844, SR) | Check |
| Whole-wheat roti | 297 / 9.6 / 56 / 3.7 | 299 / 7.8 / 46.1 / 9.2 | Bread, chapati or roti, whole wheat, commercially prepared, frozen (174075, SR) | Check |
| Chaat masala | 250 / 10 / 50 / 3 | — | spice blend — used in pinches | Other source |
| Chilli bean paste | 180 / 8 / 20 / 8 | — | doubanjiang — brand labels | Other source |
| Coconut chutney | 200 / 3 / 8 / 18 | — | home recipe | Other source |
| Curry leaves | 108 / 6 / 19 / 1 | — | IFCT 2017 | Other source |
| Halloumi | 321 / 21 / 2 / 25 | — | not in USDA — brand labels | Other source |
| Labneh | 160 / 8 / 4 / 13 | — | not in USDA — brand labels | Other source |
| Makhana | 347 / 9.7 / 77 / 0.1 | — | IFCT 2017 (fox nut); USDA lotus seed 332 kcal is a different plant | Other source |
| Mint chutney | 60 / 2 / 8 / 2 | — | home recipe | Other source |
| Paneer | 265 / 18 / 1.2 / 21 | — | IFCT 2017 (FNDDS 'paneer' has 22 g carbs — not plain paneer) | Other source |
| Poha | 350 / 6.6 / 77 / 1.2 | — | IFCT 2017 (flattened rice, DRY) | Other source |
| Roasted chana | 369 / 22 / 58 / 5 | — | IFCT 2017 | Other source |
| Salt | 0 / 0 / 0 / 0 | — | no calories | Other source |
| Salt & pepper | 0 / 0 / 0 / 0 | — | no calories | Other source |
| Seaweed snacks | 420 / 10 / 35 / 28 | — | brand labels (roasted, oiled sheets) | Other source |
| Skyr | 63 / 11 / 4 / 0.2 | — | not in USDA — brand labels | Other source |
| Tajín | 0 / 0 / 0 / 0 | — | chilli-lime salt, pinches | Other source |
| Yoghurt dressing | 80 / 4 / 5 / 4.5 | — | home recipe | Other source |
| Za'atar | 300 / 9 / 40 / 14 | — | spice blend — brand labels | Other source |
| Almond butter | 614 / 21 / 19 / 56 | 614 / 21 / 18.8 / 55.5 | Nuts, almond butter, plain, without salt added (168588, SR) | OK |
| Almonds | 579 / 21 / 22 / 50 | 579 / 21.1 / 21.6 / 49.9 | Nuts, almonds (170567, SR) | OK |
| Apple | 52 / 0.3 / 14 / 0.2 | 52 / 0.3 / 13.8 / 0.2 | Apples, raw, with skin (Includes foods for USDA's Food Distribution Program) (171688, SR) | OK |
| Asparagus | 20 / 2.2 / 3.9 / 0.1 | 20 / 2.2 / 3.9 / 0.1 | Asparagus, raw (168389, SR) | OK |
| Aubergine | 25 / 1 / 6 / 0.2 | 25 / 1 / 5.9 / 0.2 | Eggplant, raw (169228, SR) | OK |
| Avocado | 160 / 2 / 8.5 / 15 | 160 / 2 / 8.5 / 14.7 | Avocados, raw, all commercial varieties (171705, SR) | OK |
| Baby potatoes | 77 / 2 / 17 / 0.1 | 70 / 1.9 / 15.9 / 0.1 | Potatoes, red, flesh and skin, raw (170029, SR) | OK |
| Bagel | 257 / 10 / 50 / 1.6 | 275 / 10.5 / 53.4 / 1.6 | Bagels, plain, enriched, without calcium propionate (includes onion, poppy, sesame) (175049, SR) | OK |
| Banana | 89 / 1.1 / 23 / 0.3 | 89 / 1.1 / 22.8 / 0.3 | Bananas, raw (173944, SR) | OK |
| Basmati rice | 130 / 2.7 / 28 / 0.3 | 130 / 2.7 / 28.2 / 0.3 | Rice, white, long-grain, regular, enriched, cooked (168878, SR) | OK |
| Bean sprouts | 30 / 3 / 6 / 0.2 | 30 / 3 / 5.9 / 0.2 | Mung beans, mature seeds, sprouted, raw (169957, SR) | OK |
| Black beans | 132 / 8.9 / 24 / 0.5 | 132 / 8.9 / 23.7 / 0.5 | Beans, black, mature seeds, cooked, boiled, without salt (173735, SR) | OK |
| Blueberries | 57 / 0.7 / 14 / 0.3 | 57 / 0.7 / 14.5 / 0.3 | Blueberries, raw (171711, SR) | OK |
| Broccoli | 34 / 2.8 / 7 / 0.4 | 34 / 2.8 / 6.6 / 0.4 | Broccoli, raw (170379, SR) | OK |
| Brown rice | 123 / 2.7 / 26 / 1 | 123 / 2.7 / 25.6 / 1 | Rice, brown, long-grain, cooked (Includes foods for USDA's Food Distribution Program) (169704, SR) | OK |
| Bulgur | 83 / 3.1 / 19 / 0.2 | 83 / 3.1 / 18.6 / 0.2 | Bulgur, cooked (170287, SR) | OK |
| Butter | 717 / 0.9 / 0.1 / 81 | 717 / 0.8 / 0.1 / 81.1 | Butter, salted (173410, SR) | OK |
| Buttermilk | 40 / 3.3 / 4.8 / 0.9 | 40 / 3.3 / 4.8 / 1.1 | Milk, buttermilk, fluid, cultured, lowfat (170874, SR) | OK |
| Cabbage | 25 / 1.3 / 6 / 0.1 | 25 / 1.3 / 5.8 / 0.1 | Cabbage, raw (169975, SR) | OK |
| Cannellini beans | 114 / 7.8 / 20 / 0.4 | 114 / 7.3 / 21.2 / 0.3 | Beans, white, mature seeds, canned (175204, SR) | OK |
| Carrot | 41 / 0.9 / 10 / 0.2 | 41 / 0.9 / 9.6 / 0.2 | Carrots, raw (170393, SR) | OK |
| Cashews | 553 / 18 / 30 / 44 | 553 / 18.2 / 30.2 / 43.9 | Nuts, cashew nuts, raw (170162, SR) | OK |
| Celery | 16 / 0.7 / 3 / 0.2 | 14 / 0.7 / 3 / 0.2 | Celery, raw (169988, SR) | OK |
| Cheddar | 403 / 25 / 1.3 / 33 | 408 / 23.3 / 2.4 / 34 | Cheese, cheddar (328637, FF) | OK |
| Cherry tomato | 18 / 0.9 / 3.9 / 0.2 | 18 / 0.9 / 3.9 / 0.2 | Tomatoes, red, ripe, raw, year round average (170457, SR) | OK |
| Chia seeds | 486 / 17 / 42 / 31 | 486 / 16.5 / 42.1 / 30.7 | Seeds, chia seeds, dried (170554, SR) | OK |
| Chicken mince | 143 / 17 / 0 / 8 | 143 / 17.4 / 0 / 8.1 | Chicken, ground, raw (171116, SR) | OK |
| Chickpea flour | 387 / 22 / 58 / 6.7 | 387 / 22.4 / 57.8 / 6.7 | Chickpea flour (besan) (174288, SR) | OK |
| Chickpeas | 164 / 8.9 / 27 / 2.6 | 164 / 8.9 / 27.4 / 2.6 | Chickpeas (garbanzo beans, bengal gram), mature seeds, cooked, boiled, without salt (173757, SR) | OK |
| Coconut | 354 / 3.3 / 15 / 33 | 354 / 3.3 / 15.2 / 33.5 | Nuts, coconut meat, raw (170169, SR) | OK |
| Coconut milk | 197 / 2 / 3 / 21 | 197 / 2 / 2.8 / 21.3 | Nuts, coconut milk, canned (liquid expressed from grated meat and water) (170173, SR) | OK |
| Cod | 82 / 18 / 0 / 0.7 | 82 / 17.8 / 0 / 0.7 | Fish, cod, Atlantic, raw (171955, SR) | OK |
| Coriander | 23 / 2.1 / 3.7 / 0.5 | 23 / 2.1 / 3.7 / 0.5 | Coriander (cilantro) leaves, raw (169997, SR) | OK |
| Corn | 96 / 3.4 / 21 / 1.5 | 96 / 3.4 / 21 / 1.5 | Corn, sweet, yellow, cooked, boiled, drained, without salt (169999, SR) | OK |
| Cos lettuce | 17 / 1.2 / 3.3 / 0.3 | 17 / 1.2 / 3.3 / 0.3 | Lettuce, cos or romaine, raw (169247, SR) | OK |
| Cottage cheese | 98 / 11 / 3.4 / 4.3 | 98 / 11.1 / 3.4 / 4.3 | Cheese, cottage, creamed, large or small curd (172179, SR) | OK |
| Courgette | 17 / 1.2 / 3.1 / 0.3 | 17 / 1.2 / 3.1 / 0.3 | Squash, summer, zucchini, includes skin, raw (169291, SR) | OK |
| Cucumber | 15 / 0.7 / 3.6 / 0.1 | 15 / 0.7 / 3.6 / 0.1 | Cucumber, with peel, raw (168409, SR) | OK |
| Cumin | 375 / 18 / 44 / 22 | 375 / 17.8 / 44.2 / 22.3 | Spices, cumin seed (170923, SR) | OK |
| Dates | 282 / 2.5 / 75 / 0.4 | 277 / 1.8 / 75 / 0.1 | Dates, medjool (168191, SR) | OK |
| Edamame | 121 / 12 / 9 / 5 | 121 / 11.9 / 8.9 / 5.2 | Edamame, frozen, prepared (168411, SR) | OK |
| Eggs | 143 / 13 / 0.7 / 9.5 | 143 / 12.6 / 0.7 / 9.5 | Egg, whole, raw, fresh (171287, SR) | OK |
| Falafel | 333 / 13 / 32 / 18 | 333 / 13.3 / 31.8 / 17.8 | Falafel, home-prepared (172455, SR) | OK |
| Fava beans | 110 / 7.6 / 20 / 0.4 | 110 / 7.6 / 19.6 / 0.4 | Broadbeans (fava beans), mature seeds, cooked, boiled, without salt (173753, SR) | OK |
| Feta | 264 / 14 / 4 / 21 | 265 / 14.2 / 3.9 / 21.5 | Cheese, feta (173420, SR) | OK |
| Firm tofu | 144 / 17 / 3 / 8.7 | 144 / 17.3 / 2.8 / 8.7 | Tofu, raw, firm, prepared with calcium sulfate (172475, SR) | OK |
| Fish sauce | 35 / 5 / 3.6 / 0 | 35 / 5.1 / 3.6 / 0 | Sauce, fish, ready-to-serve (174531, SR) | OK |
| Frozen berries | 50 / 0.7 / 12 / 0.3 | 56 / 1.1 / 12.6 / 0.8 | Raspberries, frozen, red, unsweetened (168209, SR) | OK |
| Garlic | 149 / 6.4 / 33 / 0.5 | 149 / 6.4 / 33.1 / 0.5 | Garlic, raw (169230, SR) | OK |
| Garlic powder | 331 / 17 / 73 / 0.7 | 331 / 16.6 / 72.7 / 0.7 | Spices, garlic powder (171325, SR) | OK |
| Ghee | 900 / 0 / 0 / 100 | 900 / 0 / 0 / 100 | Butter, Clarified butter (ghee) (171314, SR) | OK |
| Ginger | 80 / 1.8 / 18 / 0.8 | 80 / 1.8 / 17.8 / 0.8 | Ginger root, raw (169231, SR) | OK |
| Greek yoghurt | 97 / 9 / 3.9 / 5 | 97 / 9 / 4 / 5 | Yogurt, Greek, plain, whole milk (171304, SR) | OK |
| Green beans | 31 / 1.8 / 7 / 0.2 | 31 / 1.8 / 7 / 0.2 | Beans, snap, green, raw (169961, SR) | OK |
| Green lentils | 116 / 9 / 20 / 0.4 | 116 / 9 / 20.1 / 0.4 | Lentils, mature seeds, cooked, boiled, without salt (172421, SR) | OK |
| Green peas | 81 / 5.4 / 14 / 0.4 | 78 / 5.2 / 14.3 / 0.3 | Peas, green, frozen, cooked, boiled, drained, without salt (170017, SR) | OK |
| Green pepper | 20 / 0.9 / 4.6 / 0.2 | 20 / 0.9 / 4.6 / 0.2 | Peppers, sweet, green, raw (170427, SR) | OK |
| Greens | 20 / 2 / 3 / 0.3 | 23 / 2.9 / 3.6 / 0.4 | Spinach, raw (168462, SR) | OK |
| Guacamole | 155 / 2 / 8.5 / 14 | 155 / 1.9 / 8.4 / 14.2 | Guacamole, NFS (2709307, FNDDS) | OK |
| Honey | 304 / 0.3 / 82 / 0 | 304 / 0.3 / 82.4 / 0 | Honey (169640, SR) | OK |
| Hung curd | 98 / 9 / 4 / 5 | 97 / 9 / 4 / 5 | Yogurt, Greek, plain, whole milk (171304, SR) | OK |
| Jasmine rice | 129 / 2.7 / 28 / 0.3 | 130 / 2.7 / 28.2 / 0.3 | Rice, white, long-grain, regular, enriched, cooked (168878, SR) | OK |
| Kidney beans | 127 / 8.7 / 23 / 0.5 | 127 / 8.7 / 22.8 / 0.5 | Beans, kidney, all types, mature seeds, cooked, boiled, without salt (173740, SR) | OK |
| Lamb mince | 282 / 17 / 0 / 23 | 282 / 16.6 / 0 / 23.4 | Lamb, ground, raw (174370, SR) | OK |
| Lemon | 29 / 1.1 / 9 / 0.3 | 29 / 1.1 / 9.3 / 0.3 | Lemons, raw, without peel (167746, SR) | OK |
| Lettuce | 15 / 1.4 / 2.9 / 0.2 | 15 / 1.4 / 2.9 / 0.1 | Lettuce, green leaf, raw (169249, SR) | OK |
| Lettuce cups | 15 / 1.4 / 2.9 / 0.2 | 14 / 0.9 / 3 / 0.1 | Lettuce, iceberg (includes crisphead types), raw (169248, SR) | OK |
| Lime | 30 / 0.7 / 11 / 0.2 | 30 / 0.7 / 10.5 / 0.2 | Limes, raw (168155, SR) | OK |
| Mango | 60 / 0.8 / 15 / 0.4 | 60 / 0.8 / 15 / 0.4 | Mangos, raw (169910, SR) | OK |
| Maple syrup | 260 / 0 / 67 / 0.1 | 260 / 0 / 67 / 0.1 | Syrups, maple (169661, SR) | OK |
| Milk | 50 / 3.4 / 4.8 / 2 | 50 / 3.3 / 4.8 / 2 | Milk, reduced fat, fluid, 2% milkfat, with added vitamin A and vitamin D (171267, SR) | OK |
| Mint | 44 / 3.3 / 8 / 0.7 | 44 / 3.3 / 8.4 / 0.7 | Spearmint, fresh (173475, SR) | OK |
| Mixed nuts | 607 / 20 / 21 / 54 | 607 / 19.5 / 22.4 / 53.5 | Nuts, mixed nuts, dry roasted, with peanuts, without salt added (170585, SR) | OK |
| Mixed veg | 65 / 2.6 / 13 / 0.3 | 65 / 2.9 / 13.1 / 0.1 | Vegetables, mixed, frozen, cooked, boiled, drained, without salt (170472, SR) | OK |
| Moong dal | 347 / 24 / 63 / 1.2 | 347 / 23.9 / 62.6 / 1.1 | Mung beans, mature seeds, raw (174256, SR) | OK |
| Moong sprouts | 30 / 3 / 6 / 0.2 | 30 / 3 / 5.9 / 0.2 | Mung beans, mature seeds, sprouted, raw (169957, SR) | OK |
| Mushrooms | 22 / 3.1 / 3.3 / 0.3 | 22 / 3.1 / 3.3 / 0.3 | Mushrooms, white, raw (169251, SR) | OK |
| Olive oil | 884 / 0 / 0 / 100 | 884 / 0 / 0 / 100 | Oil, olive, salad or cooking (171413, SR) | OK |
| Olives | 115 / 0.8 / 6 / 11 | 116 / 0.8 / 6 / 10.9 | Olives, ripe, canned (small-extra large) (169094, SR) | OK |
| Onion | 40 / 1.1 / 9 / 0.1 | 40 / 1.1 / 9.3 / 0.1 | Onions, raw (170000, SR) | OK |
| Pak choi | 13 / 1.5 / 2.2 / 0.2 | 13 / 1.5 / 2.2 / 0.2 | Cabbage, chinese (pak-choi), raw (170390, SR) | OK |
| Panko | 395 / 13 / 72 / 5.3 | 395 / 13.3 / 72 / 5.3 | Bread, crumbs, dry, grated, plain (174928, SR) | OK |
| Paprika | 282 / 14 / 54 / 13 | 282 / 14.1 / 54 / 12.9 | Spices, paprika (171329, SR) | OK |
| Parsley | 36 / 3 / 6 / 0.8 | 36 / 3 / 6.3 / 0.8 | Parsley, fresh (170416, SR) | OK |
| Peanut butter | 588 / 25 / 20 / 50 | 598 / 22.2 / 22.3 / 51.4 | Peanut butter, smooth style, without salt (172470, SR) | OK |
| Peanuts | 567 / 26 / 16 / 49 | 567 / 25.8 / 16.1 / 49.2 | Peanuts, all types, raw (172430, SR) | OK |
| Pear | 57 / 0.4 / 15 / 0.1 | 57 / 0.4 / 15.2 / 0.1 | Pears, raw (169118, SR) | OK |
| Pineapple | 50 / 0.5 / 13 / 0.1 | 50 / 0.5 / 13.1 / 0.1 | Pineapple, raw, all varieties (169124, SR) | OK |
| Pita | 275 / 9 / 56 / 1.2 | 275 / 9.1 / 55.7 / 1.2 | Bread, pita, white, enriched (174915, SR) | OK |
| Potato | 77 / 2 / 17 / 0.1 | 77 / 2 / 17.5 / 0.1 | Potatoes, flesh and skin, raw (170026, SR) | OK |
| Pumpkin seeds | 559 / 30 / 11 / 49 | 559 / 30.2 / 10.7 / 49 | Seeds, pumpkin and squash seed kernels, dried (170556, SR) | OK |
| Quinoa | 120 / 4.4 / 21 / 1.9 | 120 / 4.4 / 21.3 / 1.9 | Quinoa, cooked (168917, SR) | OK |
| Raisins | 299 / 3.1 / 79 / 0.5 | 299 / 3.3 / 79.3 / 0.2 | Raisins, dark, seedless (Includes foods for USDA's Food Distribution Program) (168165, SR) | OK |
| Raspberries | 52 / 1.2 / 12 / 0.7 | 52 / 1.2 / 11.9 / 0.7 | Raspberries, raw (167755, SR) | OK |
| Red onion | 40 / 1.1 / 9 / 0.1 | 40 / 1.1 / 9.3 / 0.1 | Onions, raw (170000, SR) | OK |
| Red pepper | 31 / 1 / 6 / 0.3 | 26 / 1 / 6 / 0.3 | Peppers, sweet, red, raw (170108, SR) | OK |
| Rice cakes | 387 / 8 / 82 / 2.8 | 387 / 8.2 / 81.5 / 2.8 | Snacks, rice cakes, brown rice, plain, unsalted (170250, SR) | OK |
| Rice noodles | 364 / 6 / 80 / 0.6 | 364 / 6 / 80.2 / 0.6 | Rice noodles, dry (169742, SR) | OK |
| Rice paper | 333 / 6 / 77 / 0.5 | 323 / 5.9 / 72.3 / 1.1 | Rice paper (2708166, FNDDS) | OK |
| Rocket | 25 / 2.6 / 3.7 / 0.7 | 25 / 2.6 / 3.6 / 0.7 | Arugula, raw (169387, SR) | OK |
| Rye bread | 259 / 8.5 / 48 / 3.3 | 259 / 8.5 / 48.3 / 3.3 | Bread, rye (172684, SR) | OK |
| Salmon | 208 / 20 / 0 / 13 | 208 / 20.4 / 0 / 13.4 | Fish, salmon, Atlantic, farmed, raw (175167, SR) | OK |
| Salsa | 36 / 1.5 / 7 / 0.2 | 29 / 1.5 / 6.6 / 0.2 | Sauce, salsa, ready-to-serve (174524, SR) | OK |
| Semolina | 360 / 13 / 73 / 1 | 360 / 12.7 / 72.8 / 1.1 | Semolina, enriched (169715, SR) | OK |
| Sesame | 573 / 18 / 23 / 50 | 573 / 17.7 / 23.4 / 49.7 | Seeds, sesame seeds, whole, dried (170150, SR) | OK |
| Smoked salmon | 117 / 18 / 0 / 4.3 | 117 / 18.3 / 0 / 4.3 | Fish, salmon, chinook, smoked (173687, SR) | OK |
| Soba noodles | 336 / 14 / 74 / 0.7 | 336 / 14.4 / 74.6 / 0.7 | Noodles, japanese, soba, dry (168906, SR) | OK |
| Sourdough | 289 / 12 / 56 / 1.8 | 272 / 10.8 / 51.9 / 2.4 | Bread, french or vienna (includes sourdough) (172675, SR) | OK |
| Soy milk | 54 / 3.3 / 6 / 1.8 | 54 / 3.3 / 6.3 / 1.8 | Soymilk, original and vanilla, unfortified (172446, SR) | OK |
| Soy sauce | 53 / 8 / 4.9 / 0.6 | 53 / 8.1 / 4.9 / 0.6 | Soy sauce made from soy and wheat (shoyu) (174277, SR) | OK |
| Spinach | 23 / 2.9 / 3.6 / 0.4 | 23 / 2.9 / 3.6 / 0.4 | Spinach, raw (168462, SR) | OK |
| Spring onion | 32 / 1.8 / 7 / 0.2 | 32 / 1.8 / 7.3 / 0.2 | Onions, spring or scallions (includes tops and bulb), raw (170005, SR) | OK |
| Strawberries | 32 / 0.7 / 7.7 / 0.3 | 32 / 0.7 / 7.7 / 0.3 | Strawberries, raw (167762, SR) | OK |
| Sushi rice | 130 / 2.4 / 29 / 0.2 | 130 / 2.4 / 28.7 / 0.2 | Rice, white, short-grain, enriched, cooked (168882, SR) | OK |
| Sweet potato | 86 / 1.6 / 20 / 0.1 | 86 / 1.6 / 20.1 / 0.1 | Sweet potato, raw, unprepared (Includes foods for USDA's Food Distribution Program) (168482, SR) | OK |
| Tahini | 595 / 17 / 21 / 54 | 595 / 17 / 21.2 / 53.8 | Seeds, sesame butter, tahini, from roasted and toasted kernels (most common type) (170189, SR) | OK |
| Teriyaki sauce | 89 / 5.9 / 16 / 0 | 89 / 5.9 / 15.6 / 0 | Sauce, teriyaki, ready-to-serve (171167, SR) | OK |
| Thai basil | 23 / 3.2 / 2.7 / 0.6 | 23 / 3.1 / 2.6 / 0.6 | Basil, fresh (172232, SR) | OK |
| Tinned tomato | 32 / 1.6 / 7 / 0.3 | 32 / 1.6 / 7.3 / 0.3 | Tomatoes, crushed, canned (170501, SR) | OK |
| Tinned tuna | 116 / 26 / 0 / 1 | 116 / 25.5 / 0 / 0.8 | Fish, tuna, light, canned in water, without salt, drained solids (171986, SR) | OK |
| Tomato | 18 / 0.9 / 3.9 / 0.2 | 18 / 0.9 / 3.9 / 0.2 | Tomatoes, red, ripe, raw, year round average (170457, SR) | OK |
| Tomato sauce | 29 / 1.3 / 6 / 0.2 | 24 / 1.2 / 5.3 / 0.3 | Tomato products, canned, sauce (170054, SR) | OK |
| Toor dal | 343 / 22 / 63 / 1.5 | 343 / 21.7 / 62.8 / 1.5 | Pigeon peas (red gram), mature seeds, raw (172436, SR) | OK |
| Tortillas | 304 / 8 / 50 / 8 | 297 / 8 / 49.3 / 7.6 | Tortillas, ready-to-bake or -fry, flour, shelf stable (167535, SR) | OK |
| Turkey mince | 149 / 20 / 0 / 8 | 148 / 19.7 / 0 / 7.7 | Turkey, Ground, raw (171505, SR) | OK |
| Tzatziki | 90 / 4 / 4 / 6.5 | 91 / 5.2 / 4.1 / 6 | Tzatziki dip (2705448, FNDDS) | OK |
| Vegetable stock | 5 / 0.2 / 1 / 0 | 5 / 0.2 / 0.9 / 0.1 | Soup, vegetable broth, ready to serve (171583, SR) | OK |
| Walnuts | 654 / 15 / 14 / 65 | 654 / 15.2 / 13.7 / 65.2 | Nuts, walnuts, english (170187, SR) | OK |
| White fish | 90 / 19 / 0 / 1 | 96 / 20.1 / 0 / 1.7 | Fish, tilapia, raw (175176, SR) | OK |
| Whole-grain bread | 252 / 12 / 43 / 3.5 | 252 / 12.4 / 42.7 / 3.5 | Bread, whole-wheat, commercially prepared (172688, SR) | OK |
| Wholewheat pasta | 348 / 13 / 72 / 2.5 | 352 / 13.9 / 73.4 / 2.9 | Pasta, whole-wheat, dry (Includes foods for USDA's Food Distribution Program) (169738, SR) | OK |
