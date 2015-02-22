package main

type AuthLogin struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AuthToken struct {
	Token string `json:"auth_token"`
}

type DeleteAccount struct {
	Username string `json:"username"`
}

type AddAccount struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Role     Role
}

type Role struct {
	Name string `json:"name"`
}

func (c *Client) Login(username, password string) error {
	login := AuthLogin{
		Username: username,
		Password: password,
	}
	var auth AuthToken
	if err := c.post(200, "/auth/login", &login, &auth); err != nil {
		return err
	}
	c.Username = username
	c.Token = auth.Token
	return nil
}

func (c *Client) AddAccount(username, password string) error {
	account := AddAccount{
		Username: username,
		Password: password,
		Role: Role{
			Name: "admin",
		},
	}
	if err := c.post(204, "/api/accounts", &account, nil); err != nil {
		return err
	}
	return nil
}

func (c *Client) DeleteAccount(username string) error {
	account := DeleteAccount{
		Username: username,
	}
	if err := c.delete(204, "/api/accounts", &account, nil); err != nil {
		return err
	}
	return nil
}
