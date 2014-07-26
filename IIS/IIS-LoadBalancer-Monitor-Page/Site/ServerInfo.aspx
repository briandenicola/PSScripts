<%@ Page Language="C#" %>
<%@ Import Namespace="System.Web" %>

<html>
    <head>
	    <script runat="server">
		    public void Page_Load ( object send, EventArgs e ) 
	        {
                string _request = string.Empty;
			    HttpContext _ctx = HttpContext.Current;

			    lblTime.Text = DateTime.Now.ToString();
			    lblUser.Text = _ctx.Request.ServerVariables["LOGON_USER"];

                _request = _ctx.Request.ServerVariables["HTTP_Reverse_VIA"]; 
                if( string.IsNullOrEmpty(_request) ) {
			        lblTMG.Text = "Internal";
                }
                else {
                    lblTMG.Text = "External";
                }
		    }
	    </script>
    </head>
	<body style="FONT: 8pt verdana">
		<form runat="server">
			The server name is: <%=System.Net.Dns.GetHostName().ToString() %> <BR/>
			The time is now: <asp:Label id="lblTime" runat="server" /> <BR/>
            The Logged On User : <asp:Label id="lblUser" runat="server" /> <BR/>
			The Request is Source : <asp:Label id="lblTMG" runat="server" /> <BR/>
            <hr/>
	</form>
	</body>
</html>
