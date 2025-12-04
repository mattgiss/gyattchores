-- Migration: Update player names
-- Date: 2025-12-03
-- Description:
--   - Change "Iris" to "BeKindHearted"
--   - Change "Mateo" to "MegoDinoLava"

-- Update player names
UPDATE players
SET name = 'BeKindHearted'
WHERE name = 'Iris';

UPDATE players
SET name = 'MegoDinoLava'
WHERE name = 'Mateo';
