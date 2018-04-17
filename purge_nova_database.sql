USE nova;

SET @days = 7;

DELETE FROM instance_actions_events WHERE action_id IN
  (SELECT id FROM instance_actions WHERE instance_uuid IN
    (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY));

DELETE FROM instance_actions WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM instance_extra WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM block_device_mapping WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM migrations WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM instance_faults WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM instance_system_metadata WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM instance_info_caches WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM instance_metadata WHERE instance_uuid IN
  (SELECT uuid FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY);

DELETE FROM instances WHERE instances.deleted != 0 AND instances.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY;

DELETE FROM reservations WHERE reservations.deleted != 0 AND reservations.deleted_at < UTC_TIMESTAMP() - INTERVAL @days DAY;
