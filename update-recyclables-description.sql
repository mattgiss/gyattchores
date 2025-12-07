-- Add Definition of Done for Take Recyclables to Curb
UPDATE chores
SET description = 'Take the recycling bin to the curb on the right side of the driveway. Bring the empty bin back the next day and put it back in its spot.'
WHERE name = 'Take Recyclables to Curb';

-- Verify it worked
SELECT name, description
FROM chores
WHERE name = 'Take Recyclables to Curb';
