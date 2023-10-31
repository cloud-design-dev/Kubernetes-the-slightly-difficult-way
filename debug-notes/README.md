# Debug Notes

## Flowlogs

### Create table definition for our flowlogs

```sql
-- Table definition for flow logs 
CREATE TABLE FLOW( 
version string, 
collector_crn string, 
attached_endpoint_type string, 
network_interface_id string, 
instance_crn string, 
capture_start_time timestamp, 
capture_end_time timestamp, 
number_of_flow_logs int, 
flow_logs array<struct< 
    start_time: string, 
    end_time: string, 
    connection_start_time: string, 
    direction: string,
    action: string, 
    initiator_ip: string, 
    target_ip: string, 
    initiator_port: int, 
    target_port: int, 
    transport_protocol: int, 
    ether_type: string, 
    was_initiated: boolean, 
    was_terminated: boolean, 
    bytes_from_initiator: long, 
    packets_from_initiator: long, 
    bytes_from_target: long, 
    packets_from_target: long, 
    cumulative_bytes_from_initiator: long, 
    cumulative_packets_from_initiator: long, 
    cumulative_bytes_from_target: long, 
    cumulative_packets_from_target: long 
>>, 
account string, 
region string, 
`vpc-id` string, 
`subnet-id` string, 
`endpoint-type` string, 
`instance-id` string, 
`vnic-id` string, 
`record-type` string, 
year int, 
month int, 
day int, 
hour int, 
`stream-id` string 
) USING JSON LOCATION cos://ca-tor/k8srtv1-worker-0-flowlogs-collector-bucket/ibm_vpc_flowlogs_v1/
```

### Create FLOW_FLAT view

```sql
CREATE VIEW FLOW_FLAT AS 
WITH EXPLODED_FLOW as ( 
    SELECT 
        version,
        collector_crn,
        attached_endpoint_type,
        network_interface_id, 
        instance_crn, 
        capture_start_time, 
        capture_end_time, 
        `vnic-id`, 
        `record-type`, 
        year, 
        month, 
        day,
        hour, 
        `stream-id`, 
         explode(flow_logs) as flow 
    FROM FLOW) 
SELECT 
    version, 
    collector_crn, 
    attached_endpoint_type, 
    network_interface_id, 
    instance_crn, 
    capture_start_time, 
    capture_end_time, 
    `vnic-id`, 
    `record-type`, 
    year, 
    month, 
    day, 
    hour, 
    `stream-id`, 
    flow.* 
FROM 
    EXPLODED_FLOW

```