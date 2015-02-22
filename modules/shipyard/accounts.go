package main

type AuthLogin struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AuthToken struct {
	Token string `json:"auth_token"`
}

func (c *Client) Login(username, password string) error {
	login := AuthLogin{
		Username: username,
		Password: password,
	}
	var auth AuthToken

	if err := c.post("/auth/login", login, auth); err != nil {
		return err
	}
	c.Token = auth.Token
	return nil
}
