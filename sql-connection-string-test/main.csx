#!/usr/bin/env dotnet-script
#r "nuget: Microsoft.Data.SqlClient, 5.1.2"

using System;
using Microsoft.Data.SqlClient;


/*
PaaS Code:

return new SqlConnectionStringBuilder
{
    DataSource = $"tcp:{sqlConnectionInfoDto.ServerName}{_fhirServiceEnvironment.SQLDomainSuffix},1433",
    InitialCatalog = sqlConnectionInfoDto.DatabaseName,
    UserID = sqlConnectionInfoDto.Username,
    Password = sqlConnectionInfoDto.Password,
    PersistSecurityInfo = false,
    MultipleActiveResultSets = false,
    Encrypt = true,
    TrustServerCertificate = false,
    ConnectTimeout = 30,
    Authentication = SqlAuthenticationMethod.SqlPassword,
}.ConnectionString
*/

var connectionString = new SqlConnectionStringBuilder
{
    /*
    Our DB
    */
    DataSource = "tcp:***REMOVED***.database.windows.net,1433",
    InitialCatalog = "***REMOVED***",
    UserID = "***REMOVED***-user-1",
    Password = "***REMOVED***",

    /*
    Test System
    DataSource = "tcp:***REMOVED***.database.windows.net,1433",
    InitialCatalog = "***REMOVED***",
    UserID = "***REMOVED***-user-1",
    Password = "***REMOVED***",
    */

    PersistSecurityInfo = false,
    MultipleActiveResultSets = false,
    Encrypt = true,
    TrustServerCertificate = false,
    ConnectTimeout = 30,
    Authentication = SqlAuthenticationMethod.SqlPassword,
}.ConnectionString;


Console.WriteLine(connectionString);

try
{
    using (SqlConnection connection = new SqlConnection(connectionString))
    {
        connection.Open();
        Console.WriteLine("Connection successful.");

        // Example of a scalar command
        string commandText = "SELECT @@DBTS"; // or "SELECT 1" for a simple test
        using (SqlCommand command = new SqlCommand(commandText, connection))
        {
            object result = command.ExecuteScalar();
            if (result != null)
            {
                Console.WriteLine("Scalar command executed successfully.");
                Console.WriteLine("Result: " + result);
            }
            else
            {
                Console.WriteLine("No result returned.");
            }
        }
    }
}
catch (SqlException e)
{
    Console.WriteLine("Error occurred while connecting to the database:");
    Console.WriteLine(e.Message);
}
