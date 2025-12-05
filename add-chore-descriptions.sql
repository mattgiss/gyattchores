-- Add description column to chores table (if it doesn't already exist)
-- Run this in Supabase SQL Editor

-- The description column already exists in the schema, so we just need to update the values
UPDATE chores SET description = 'Pick up all dog poop from the backyard using a bag. Put the bag in the outdoor trash can. Check the whole yard - don''t miss any!' WHERE name = 'Pick up Poop';

UPDATE chores SET description = 'Vacuum the entire living room floor including under the coffee table. Move small items if needed. Empty the vacuum if it''s full. Put the vacuum away.' WHERE name = 'Vacuum Living Room';

UPDATE chores SET description = 'Walk to the mailbox, get all the mail, and bring it inside. Put it on the kitchen counter in the mail spot.' WHERE name = 'Get Mail';

UPDATE chores SET description = 'Take the kitchen trash bag to the outside trash can. Put a new bag in the kitchen trash can. Make sure the lid closes on the outside can.' WHERE name = 'Take Out Trash';

UPDATE chores SET description = 'Wash all dishes in the sink by hand with soap and hot water. Rinse them clean. Put them in the drying rack or dry and put away. Wipe down the sink when done.' WHERE name = 'Wash Dishes';

UPDATE chores SET description = 'Put all dirty dishes from the sink into the dishwasher. Scrape off food first. Add detergent pod. Start the dishwasher. Wipe down the sink and counter.' WHERE name = 'Load Dishwasher';

UPDATE chores SET description = 'Put away all clean dishes from the dishwasher into the correct cabinets and drawers. Make sure everything is put in the right place. Close all cabinets and drawers.' WHERE name = 'Unload Dishwasher';

UPDATE chores SET description = 'Make your bed. Put all clothes in hamper or drawers. Put all toys and books away. Nothing on the floor except furniture. Trash in trash can.' WHERE name = 'Clean Room';

UPDATE chores SET description = 'Water all the house plants until water drains into the saucer. Don''t overwater! Check the soil - if it''s already wet, they don''t need water.' WHERE name = 'Water Plants';

UPDATE chores SET description = 'Fill the dog''s food bowl with one scoop of food. Make sure the water bowl is full with fresh water. Check that both bowls are clean.' WHERE name = 'Feed Pet';

UPDATE chores SET description = 'Sweep the kitchen floor and dining area. Get all the crumbs and dirt into a pile. Use the dustpan to pick it up. Throw it in the trash. Put the broom away.' WHERE name = 'Sweep Floor';

UPDATE chores SET description = 'Wipe all kitchen counters with a damp cloth or spray. Move items to wipe under them. Get all the crumbs and spills. Rinse out the cloth when done.' WHERE name = 'Wipe Counters';

UPDATE chores SET description = 'Take the recycling bin from the kitchen to the outside recycling can. Empty it completely. Bring the bin back inside.' WHERE name = 'Take Out Recycling';

UPDATE chores SET description = 'Fold all clean clothes from the laundry basket. Match socks together. Stack folded clothes neatly. Put them away in your drawers or deliver to family members'' rooms.' WHERE name = 'Fold Laundry';

UPDATE chores SET description = 'Put placemats, plates, forks, knives, spoons, and napkins at each seat. Add cups if asked. Make sure everything is centered and neat.' WHERE name = 'Set Table';

UPDATE chores SET description = 'Remove all dishes, cups, and silverware from the table after the meal. Scrape food into trash. Put dishes in sink or dishwasher. Wipe the table with a damp cloth.' WHERE name = 'Clear Table';
