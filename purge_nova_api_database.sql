USE nova_api;

SET @days = 7;

DELETE FROM request_specs WHERE
  id NOT IN (SELECT request_spec_id FROM build_requests) AND
  instance_uuid NOT IN (SELECT uuid FROM nova.instances) AND
  created_at < UTC_TIMESTAMP() - INTERVAL @days DAY;
