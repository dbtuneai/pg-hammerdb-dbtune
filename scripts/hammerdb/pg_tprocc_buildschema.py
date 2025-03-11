#!/bin/tclsh
# maintainer: Pooja Jain

print("SETTING CONFIGURATION")
dbset('db','pg')
dbset('bm','TPC-C')

diset('connection','pg_host','DB_SERVER_IP')
diset('connection','pg_port','5432')
diset('connection','pg_sslmode','prefer')

vu = tclpy.eval('numberOfCPUs')
warehouse = 500
diset('tpcc','pg_count_ware',500)
diset('tpcc','pg_num_vu',vu)
diset('tpcc','pg_superuser','admin')
diset('tpcc','pg_superuserpass','password')
diset('tpcc','pg_defaultdbase',' postgres')
diset('tpcc','pg_user','tpcc')
diset('tpcc','pg_pass','tpcc')
diset('tpcc','pg_dbase','tpcc')
diset('tpcc','pg_tspace','pg_default')
if (warehouse >= 200): 
    diset('tpcc','pg_partition','true') 
else:
    diset('tpcc','pg_partition','false') 

print("SCHEMA BUILD STARTED")
buildschema()
print("SCHEMA BUILD COMPLETED")
exit()
