trello2wr
=========

Generates weekly work report (A&amp;O) from Trello board


#### config .yml  (~/.trello2wr/config.yml )
trello:
  developer_public_key: https://trello.com/1/appKey/generate (Developer API Keys)  
  secret: https://trello.com/1/appKey/generate (Developer API Keys)  
  member_token: https://trello.com/1/connect?key=DEVELOPER_PUBLIC_KEY&name=trello2wr&response_type=token&expiration=never  
  username: see Trello Profile
  boards:
    - "BOARD_NAME"  
    
email:
  client: (thunderbird |  kmail | evolition)  
  sender: email  
  recipient: email  
  cc: email
  

