$http = [System.Net.HttpListener]::new() 

$http.Prefixes.Add("http://localhost:8080/")

# Start the Http Server 
$http.Start()



# Log ready message to terminal 
if ($http.IsListening) {
    write-host " HTTP Server Ready!  " -f 'black' -b 'gre'
    write-host "now try going to $($http.Prefixes)" -f 'y'
    
}


# INFINTE LOOP
# Used to listen for requests
try {
    while ($http.IsListening) {

        $contextTask = $http.GetContextAsync()

        while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) { }
        $context = $contextTask.GetAwaiter().GetResult()

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {

            write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

            [string]$html = Get-Content "C:\monitoring\wwwroot\monitoring.html" -Raw
        
            #resposed to the request
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.ContentType = 'text/html; charset=utf-8'
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
    
        }

        # ROUTE EXAMPLE 2
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/result/') {

            # We can log the request to the terminal
            write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

            [string]$html = Get-Content "C:\monitoring\result\result.json" -Raw
        
            #resposed to the request
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.ContentType = 'application/json; charset=utf-8'
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        } 
        
        # ROUTE EXAMPLE 
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/diagram.png') {

            # We can log the request to the terminal
            write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

            $buffer = Get-Content "C:\monitoring\result\diagram.png" -Raw
        
            #resposed to the request
            # $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
            
            $context.Response.ContentType = 'image/png'
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }


        # powershell will continue looping and listen for new requests...

    }
}
finally {
    $http.Stop()
}