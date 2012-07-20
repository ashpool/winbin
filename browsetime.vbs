'----------------------------------------------------------------------------------------------------------------------------
'Script Name : browsetime.vbs   
'Author      : Magnus Ljadas (Original author Matthew Beattie)   
'Description : This script makes Internet Explorer to continually navigate to a url, wait a specified
'            : number of seconds, close Internet explorer and repeat the same process after waiting for 5 seconds.
'----------------------------------------------------------------------------------------------------------------------------
'Initialization  Section   
'----------------------------------------------------------------------------------------------------------------------------
Option Explicit 
Dim WshShell
On Error Resume Next      
   Set wshShell = CreateObject("Wscript.Shell")
   If Err.Number <> 0 Then
      Wscript.Quit
   End If
On Error Goto 0
'----------------------------------------------------------------------------------------------------------------------------
'Main Processing Section   
'----------------------------------------------------------------------------------------------------------------------------
On Error Resume Next     
   ProcessScript
   If Err.Number <> 0 Then
      Wscript.Quit
   End If
On Error Goto 0
'----------------------------------------------------------------------------------------------------------------------------
'Functions Processing Section
'----------------------------------------------------------------------------------------------------------------------------
'Name       : ProcessScript -> Primary Function that controls all other script processing.
'Parameters : None          -> 
'Return     : None          ->
'----------------------------------------------------------------------------------------------------------------------------
Function ProcessScript
   Dim browseTime, url
   browseTime  = 15

   If WScript.Arguments.Count = 1 Then
      Wscript.Echo "Fooo"
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
'----------------------------------------------------------------------------------------------------------------------------
