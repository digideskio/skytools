
create or replace function pgq_node.drop_node(
    in i_queue_name text,
    in i_node_name text,
    out ret_code int4,
    out ret_note text)
returns record as $$
-- ----------------------------------------------------------------------
-- Function: pgq_node.drop_node(2)
--
--      Drop node. This needs to be run on all the members of a set
--      to properly get rid of the node.
--
-- Parameters:
--      i_queue_name - queue name
--      i_node_name - node_name
--
-- Returns:
--      ret_code - error code
--      ret_note - error description
--
-- Return Codes:
--      200 - Ok
--      304 - No such queue
------------------------------------------------------------------------
declare
    _is_local   boolean;
begin
    select (node_name = i_node_name) into _is_local
    from pgq_node.node_info
      where queue_name = i_queue_name;

    if not found then
        select 304, 'No such queue: ' || i_queue_name into ret_code, ret_note;
        return;
    end if;

    begin
        perform pgq_node.unregister_subscriber(i_queue_name, i_node_name);
    exception
        when others then
            null;
    end;

    delete from pgq_node.subscriber_info
     where queue_name = i_queue_name
        and subscriber_node = i_node_name;

    if _is_local then
        delete from pgq_node.local_state
         where queue_name = i_queue_name;

        delete from pgq_node.node_info
         where queue_name = i_queue_name
            and node_name = i_node_name;

        perform pgq.drop_queue(queue_name, true)
           from pgq.queue where queue_name = i_queue_name;

        delete from pgq_node.node_location
         where queue_name = i_queue_name;
    else
        delete from pgq_node.node_location
         where queue_name = i_queue_name
            and node_name = i_node_name;
    end if;

    select 200, 'Node dropped' into ret_code, ret_note;
    return;
end;
$$ language plpgsql security definer;

