-- Update trash and recycling descriptions
-- Run this in Supabase SQL Editor

UPDATE chores
SET description = 'Take the trash can to the curb on the right side of the driveway. Bring the empty can back the next day and put it back in its spot.'
WHERE name = 'Take Out Trash';

UPDATE chores
SET description = 'Take the recycling bin to the curb on the right side of the driveway. Bring the empty bin back the next day and put it back in its spot.'
WHERE name = 'Take Out Recycling';
