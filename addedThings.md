
+! test request and notification and recent activities reception and active jobs/ new requests counting  for handyman profile page
+! add handyman service rating 
+! implement notification for handyman when new request is posted in his service category
+! implement notification and sms notifications for handyman when he is assigned to a new job
+! add user type detection at login and signup to redirect to the correct profile page (client/handyman)

+ add error management, like if no internat connection or app cant get a link like profile picture or other resources from internet
+ if a user try to login without confirmed email, should be redirected to EmailConfirmation page 
+ statistique part should be implemented
+ add translation for app 
+ add dashboard for admin for handyman management 
+ add  a section for handyman verification management for admin
+ add gps location for handyman
+ add client behavior rating to be showen to other handymen before accepting a job request from a client
+ add email verification while changing email from loged   handyman profile
+ implement picture remove from coudinary while handyman change or delete his profile picture or delete his account
+ implement delete account should delete all relative data from the app database
+ implemt help&support, terme & condition and privacy policy page for client and handyman 
+ add map integration for handyman to show his location
+ implement password reset via email for handyman


after login as client i should show here the info of the loged client with his favorite list and all his preference settings 
and all stuff related to the loged client

# ISSUES

account :handyman
 - after changing the profile picture from settings, and going back to profile page or home page, it not updated i should reload the data to see the new profile picture, but it should be updated automatically without reloading the page.
 - after changing the availability of the handyman in profile page and going to home page i see the availability not changed, i need to reload the page, but it should be updated automatically without reloading the page



 OK - booking at 13 mars is accepted from notifications (mark as completed and give 5 stars with message "you have a nice work" still cannot see the client name in review and also not added to completed tab automatically without reloading the page, should be added instantly )
  - the handyman should receive a notification if the client mark the booking as completed




 OK - booking at 10 mars is accepted from home page (mark as complete with 3 starts and message "good job man")
 handyman should receive the notification the message and rating should be seen in completed booking details for client and handyman 


 X  - booking at 11 mars is declined from notifications with message (handyman can't see the message or the motif of decline in handyman home page in details of declined booking the same thing for client cant see the motif of decline)
 X  - booking at 09 mars is declined from home page
 - booking at 08 mars still pending


 C:\Users\Windows\OneDrive\Bureau\fixilya_app\lib\features\handyman\presentation\screens\handyman_notifications_page.dart the notifications when i accept or decline from home page, but i still have the te
  accept and decline button in notification page, it should not be that

flutter run --dart-define=API_GATEWAY_URL=https://api.fixilya.pro/api
flutter run --dart-define=IS_EMULATOR=true

from all the test you did, make testPlan to do it manualy with the action, expected result, and the actual resual that i should fill by my self, make section, handyman, client, calls, booking,
  notification, admin, you find other testplan file merge it with what you are going to give me


  + after changing the profile page in handyman setting page and go back to profile page the profile picture should be updated automatiqualy and instantly without reloading the data
  + in  handyman home page, reviews section, the see all should not be shoen if there is no reviews