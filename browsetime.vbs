'----------------------------------------------------------------------------------------------------------------------------
'Script Name : browsetime.vbs   
'Author      : Magnus Ljadas (Original author Matthew Beattie)   
'Description : Are you experiencing hangups with Internet Explorer when using it to monitor, let's say, 
'            : a build server's status page? Perhaps this script can help.
'            :
'            : This script makes IE to continually navigate to an url, wait a specified
'            : number of seconds, close IE and repeat the same process after waiting for 5 seconds.
'----------------------------------------------------------------------------------------------------------------------------

Option Explicit 
Dim WshShell

On Error Resume Next      
   Set WshShell = CreateObject("Wscript.Shell")
   If Err.Number <> 0 Then
      Wscript.Quit
   End If
On Error Goto 0

On Error Resume Next     
   ProcessScript
   If Err.Number <> 0 Then
      Wscript.Quit
   End If
On Error Goto 0

Function ProcessScript
   Dim browseTime, url
   browseTime  = 60

   If WScript.Arguments.Count > 0  Then
      url = WScript.Arguments.Item(0)
   Else
      Wscript.Echo "Usage: browsetime.vbs url [browse time in seconds (default 60)]"
      Wscript.Quit
   End If
   
   If WScript.Arguments.Count = 2 Then
      browseTime = WScript.Arguments.Item(1)
   End If
      
   '-------------------------------------------------------------------------------------------------------------------------
   'Browse the url for the specified number of seconds (20 minutes) and wait 5 seconds before restarting Internet explorer.
   '-------------------------------------------------------------------------------------------------------------------------
   Do While NavigateBrowser(url, browseTime)
      Wscript.Sleep 5000
   Loop
End Function

'----------------------------------------------------------------------------------------------------------------------------
'Name       : NavigateBrowser -> Creates an instance of Internet Explorer and browses the specfied URL for a specified time.   
'Parameters : url             -> String containing the URL to navigate to.
'           : browseTime      -> Integer containing the number of seconds to browse the URL for.
'Return     : NavigateBrowser -> Returns True if successful otherwise returns False.  
'----------------------------------------------------------------------------------------------------------------------------
Function NavigateBrowser(url, ByVal browseTime)
   Dim objIE, timeOut
   NavigateBrowser = False
   On Error Resume Next
      '----------------------------------------------------------------------------------------------------------------------
      'Ensure the variable type of the functions "browseTime" Parameter is a valid Integer by explicitly converting it.
      '----------------------------------------------------------------------------------------------------------------------
      If Not varType(url) = vbInteger Then
         timeOut = CInt(browseTime)
         If Err.Number <> 0 Then
            Exit Function
         End If
      End If
      '----------------------------------------------------------------------------------------------------------------------
      'Create an instance of Internet Explorer and navigate to the url value. 
      '----------------------------------------------------------------------------------------------------------------------
      Set objIE = WScript.CreateObject("InternetExplorer.Application")
      If Err.Number <> 0 Then
         Exit Function
      End If
      With objIE
         .Navigate url     
         .fullscreen = 1
         .ToolBar    = 0
         .MenuBar    = 0
         .StatusBar  = 0
         .Visible    = 1
      End With
      '----------------------------------------------------------------------------------------------------------------------
      'Pause script processing for the value specified in the "browseTime" parameter then quit Internet Explorer.
      '----------------------------------------------------------------------------------------------------------------------
      Do while timeOut > 0
         Wscript.Sleep 1000
         timeOut = timeOut - 1
      Loop
      objIE.Quit
   On Error Goto 0
   NavigateBrowser = True
End Function
