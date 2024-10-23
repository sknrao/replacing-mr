./pnfRegister.sh 7DEV
/sendStndDefinedHeartbeat.sh
python3 sendVesHeartbeat.py
./sendFault.sh pnf2 lossOfSignal CRITICAL
./sendStndDefinedNotifyAlarm.sh pnf2 lossOfSignal CRITICAL new
./sendStndDefinedNotifyFileReady.sh pnf2
./sendStndDefinedO1NotifyPnfRegistration.sh pnf2
./send15minPm.sh pnf2
./sendTca.sh pnf2 TCA CONT
