USE cinder;

SET @days = 7;

DELETE FROM backups WHERE backups.deleted != 0 AND backups.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY;

DELETE FROM reservations WHERE reservations.deleted != 0 AND reservations.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY;

DELETE FROM volume_glance_metadata WHERE snapshot_id IN
  (SELECT id FROM snapshots WHERE volume_id IN
    (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY));

DELETE FROM snapshot_metadata WHERE snapshot_id IN
  (SELECT id FROM snapshots WHERE volume_id IN
    (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY));

DELETE FROM snapshots WHERE volume_id IN
  (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM transfers WHERE volume_id IN
  (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM volume_admin_metadata WHERE volume_id IN
  (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM volume_attachment WHERE volume_id IN
  (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM volume_glance_metadata WHERE volume_id IN
  (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM volume_metadata WHERE volume_id IN
  (SELECT id FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM volumes WHERE volumes.deleted != 0 AND volumes.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY;
