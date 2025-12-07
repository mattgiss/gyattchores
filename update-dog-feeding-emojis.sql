-- Update dog feeding chore emojis
-- Alfred gets a monocle (sophisticated butler pup)
-- Chevy gets a car (American muscle)

UPDATE chores
SET icon = '🧐'
WHERE name = 'Feed Alfred';

UPDATE chores
SET icon = '🚗'
WHERE name = 'Feed Chevy';
