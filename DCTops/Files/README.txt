DCTops Release Notes (1.2)
===============================================================
Notes:
.NET FRAMEWORK 1.1 is required for the DCTops Services.
Ensure .NET Framework 1.1 is installed before installing DCTops
===============================================================

Installation Procedures:

1.  Run DCTops setup.exe

2.  Set-up the configuration files in the DCTops folder before starting up the 
    service.
    
    There are two configuration files: 
        - DCTOPService.exe.config and 
        - DCTopsConfigs.xml.

  2.1 DCTopsService.exe.config 
      Click on "Set Configuration Path" shortcut to edit DCTopsService.exe.config

      Locate DCTopsConfigs.xml (Configure DCTops Connection) and type its full 
      path in the configFilePath in the DCTopsService.exe.config file (this will be 
      where DCTops was installed on the PC).

      For example:
      Set <add key="configFilePath" value="C:\Program Files\Softix\DCTops\DCTopsConfigs.xml"/>

  2.2 Configure DCTopsConfigs.xml
      Click on "Configure DCTops Connection" shortcut to edit DCTopsConfigs.xml

      There are two sections in the config file: 
          - global and 
          - settings.
     
      For example:
      <dctops.config>
              <global>
                      <timetoreconnect>2</timetoreconnect>
                      <maxbuffersize>2097152</maxbuffersize>            
              </global>
              <settings>
                      <printernumber>2</printernumber> 
                      <tixsyssitecode>TST1</tixsyssitecode>
                      <tixsysaddress>10.2.5.178</tixsysaddress>
                      <topsdcportnumber>13704</topsdcportnumber>
                      <tops2portnumber>1362</tops2portnumber>
                      <printercomportnumber>1</printercomportnumber>
                      <printercomsettings>19200,n,8,1</printercomsettings>
                      <printerhandshaking>XOnXOff</printerhandshaking> 
              </settings>
              .
              .	
              .
      </dctops.config>

      "global" attributes remain the same for every group of "settings" so they 
      only need to be defined once at the top of this file.

      "settings" attributes are the configurations of each individual dctops 
      printer connection used by this PC. Create as many "settings" as required.

      Global Settings:
      1. timetoreconnect - Defines the number of seconds to wait before 
         attempting the next reconnection.

      2. maxbuffersize - Defines the maximum amount of data that can be sent 
         from the Ticketing System to printer at one time.


      Settings:
      1. printernumber   - Defines the tops2 printer number.

      2. tixsyssitecode  - Defines the Ticketing System site code.

      3. tixsysaddress   - Defines the Ticketing System ip address or hostname 
         (e.g. active-1).

      4. tixsysportnumber - Defines the tops-dc-<site> TCP port number as configured 
         in /etc/services on the Ticketing System host defined above.

      5. tixsysudpportnumber  - Defines the tops2-<site> UDP port number as 
         configured in /etc/services on the Ticketing System host defined above.

      6. printercomportnumber - Defines the COM Port number on which the printer 
         is connected to the PC.

      7. printercomsettings   - Defines the communication settings of the ticket 
         printer in a comma separated list.  
         
         These are the Speed, Parity, Data Bits and Stop Bits settings 
         (e.g. 19200,n,8,1)

      8. printerhandshaking   - Defines the printer handshaking protocol.

	   Possible handshaking protocols are:
	    a. None
	    b. RTS
	    c. RTSXOnXOff
	    d. XOnXOff

3. Start and Stop the DCTops service by clicking on the "Start DCTops Service" 
   and "Stop DCTops Service" shortcuts in the DCTops directory.

===============================================================

Uninstallation Procedures:

1. Uninstall service.
   Click on "Uninstall DCTops Service" shortcut in the DCTops/Config directory.

2. Uninstall DCTops.
   Click on "Uninstall DCTops" shortcut in the DCTops/Config directory.

