#!/usr/bin/php
# Runs the OGP web install script
# By OwN-3m-All

<?php

	if(isset($argv) && count($argv) > 1){
		//extract data from the post
		extract($_POST);
		
		$realNumParams = (count($argv) -2);

		// Our fields variable
		$fields_string = "";
	
		//set POST variables
		$url = $argv[1];
		
		for ($i = 2; $i < count($argv); $i++){
			$keyVal = explode("=", $argv[$i]);
			$value=urlencode($keyVal[1]);
			$key=$keyVal[0];
			$fields_string .= $key.'='.$value.'&';
		}
		
		$handle = fopen("ogp_php_log", "a+");
		fwrite($handle, "URL is set to: " . $url . "\n");
		fwrite($handle, "Received this string of data: " . $fields_string . "\n");
		
		
		if(!empty($fields_string) && isset($fields_string)){
			rtrim($fields_string, '&');

			//open connection
			$ch = curl_init();

			//set the url, number of POST vars, POST data
			curl_setopt($ch,CURLOPT_URL, $url);
			curl_setopt($ch,CURLOPT_POST, $realNumParams);
			curl_setopt($ch,CURLOPT_POSTFIELDS, $fields_string);

			//execute post
			$result = curl_exec($ch);
			
			// Check if any error occurred
			if(curl_errno($ch))
			{
				fwrite($handle, "Curl error: " . curl_error($ch) . "\n");
			}
			
			fwrite($handle, "Result is: " . $result . "\n");

			//close connection
			curl_close($ch);
		}
		
		// Close file
		if(isset($handle)){
			fclose($handle);
		}
	}

?>

