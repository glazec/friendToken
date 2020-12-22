const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");


contract("CustomERC20TokenV1", (accounts) => {
  it("should put 20000 Token with correct symbol decimal in the first account", async () => {
    const instance = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "DAEE",
      "EE"
    );

    const balance = await instance.balanceOf(accounts[0]);
    const symbol = await instance.symbol.call()
    const tokenName = await instance.name.call()
    const decimals = await instance.decimals.call()
    assert.equal(
      balance.valueOf(),
      20000,
      "20000 wasn't in the first account"
    );
    assert.equal(
      symbol.toString(),
      "EE",
      "Incorrect token symbol"
    );
    assert.equal(
      tokenName.toString(),
      "DAEE",
      "Incorrect token Name"
    );
    assert.equal(
      decimals.toString(),
      "18",
      "Incorrect token decimals"
    );

  });
  it("should send coin correctly", async () => {
    const instance = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "DAEE",
      "EE"
    );

    // Setup 2 accounts.
    const accountOne = accounts[0];
    const accountTwo = accounts[1];

    // Get initial balances of first and second account.
    const accountOneStartingBalance = await instance.balanceOf(accountOne);
    const accountTwoStartingBalance = await instance.balanceOf(accountTwo);

    // Make transaction from first account to second.
    const amount = 10;
    await instance.transfer(accountTwo, amount, { from: accountOne });

    // Get balances of first and second account after the transactions.
    const accountOneEndingBalance = await instance.balanceOf(accountOne);
    const accountTwoEndingBalance = await instance.balanceOf(accountTwo);

    assert.equal(
      accountOneEndingBalance.toString(),
      (accountOneStartingBalance.subn(amount)).toString(),
      "Amount wasn't correctly taken from the sender"
    );
    assert.equal(
      accountTwoEndingBalance.toString(),
      accountTwoStartingBalance.addn(amount).toString(),
      "Amount wasn't correctly sent to the receiver"
    );
  });
  it("should allow recipient to take token from sender", async () => {
    const instance = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "DAEE",
      "EE"
    );
    const accountOne = accounts[0];
    const accountTwo = accounts[1];
    const accountOneStartingBalance = await instance.balanceOf(accountOne);
    const accountTwoStartingBalance = await instance.balanceOf(accountTwo);
    const allowanceStartingBalance = await instance.allowance(accountOne, accountTwo);
    const amount = 10;
    await instance.increaseAllowance(accountTwo, amount, { from: accountOne });
    const allowanceMiddleBalance = await instance.allowance(accountOne, accountTwo);
    await instance.transferFrom(accountOne, accountTwo, amount, { from: accountTwo });
    const allowanceEndingBalance = await instance.allowance(accountOne, accountTwo)
    const accountOneEndingBalance = await instance.balanceOf(accountOne);
    const accountTwoEndingBalance = await instance.balanceOf(accountTwo);

    assert.equal(
      allowanceStartingBalance.toString(),
      allowanceEndingBalance.toString(),
      'Correct Allowance after spending'
    )
    assert.equal(
      allowanceStartingBalance.addn(amount).toString(),
      allowanceMiddleBalance.toString(),
      'Correct increasing Allowance'
    )

    assert.equal(
      accountOneEndingBalance.toString(),
      (accountOneStartingBalance.subn(amount)).toString(),
      "Amount wasn't correctly taken from the sender"
    );
    assert.equal(
      accountTwoEndingBalance.toString(),
      accountTwoStartingBalance.addn(amount).toString(),
      "Amount wasn't correctly sent to the receiver"
    );
  });
  it("should add and remove friendToken correctly", async () => {
    const instance = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "DAEE",
      "EE"
    );

    const friendToken = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "AATTUU",
      "ATU"
    );
    // Setup 2 accounts.
    const accountOne = accounts[0];
    assert.equal((await instance.acceptedTokenList()).length, 0, 'Wrong AcceptedTokenList Initialization');
    await instance.setFriendToken(friendToken.address, 2);
    assert.equal((await instance.acceptedTokenList())[0], friendToken.address, 'Wrong AcceptedTokenList after adding friendToken');
    assert.equal((await instance.exchangeRatioList(friendToken.address)).toString(), '2', 'Wrong exchangeRatioList after adding friendToken');
    await instance.removeFriendToken(friendToken.address);
    assert.equal((await instance.acceptedTokenList()).length, 0, 'Wrong AcceptedTokenList after removing friendToken');
    assert.equal((await instance.exchangeRatioList(friendToken.address)).toString(), '0', 'Wrong exchangeRatioList after removing friendToken');

  });
  it("should cast and destroy coin successfully", async () => {
    const instance = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "DAEE",
      "EE"
    );
    const friendToken = await CustomERC20TokenV1.new(
      web3.utils.toBN("20000"),
      "AATTUU",
      "ATU"
    );
    const accountOne = accounts[0];
    await instance.setFriendToken(friendToken.address, 2);
    await friendToken.increaseAllowance(instance.address, 100)

    // Casting
    const accountOneAEEStartingBalance = await instance.balanceOf(accountOne);
    const accountOneATUStartingBalance = await friendToken.balanceOf(accountOne);
    await instance.cast(200);
    const accountOneAEEEndingBalance = await instance.balanceOf(accountOne);
    const accountOneATUEndingBalance = await friendToken.balanceOf(accountOne);
    assert.equal(
      accountOneAEEStartingBalance.toString(),
      (accountOneAEEEndingBalance.subn(200)).toString(),
      "Casting wrong number of token"
    );
    assert.equal(
      accountOneATUStartingBalance.toString(),
      accountOneATUEndingBalance.addn(100).toString(),
      "Staking wrong number of friend token"
    );


    //destroy
    await instance.increaseAllowance(instance.address, 200);
    console.log(await instance.allowance(accountOne, instance.address));
    await instance.destroy(200);
    const accountOneAEEDestroyingBalance = await instance.balanceOf(accountOne);
    const accountOneATUDestroyingBalance = await friendToken.balanceOf(accountOne);
    assert.equal(
      accountOneAEEStartingBalance.toString(),
      accountOneAEEDestroyingBalance.toString(),
      "Destroy wrong number of tokens"
    );
    assert.equal(
      accountOneATUStartingBalance.toString(),
      accountOneATUDestroyingBalance.toString(),
      "Unstake wrong number of friend token"
    );
  });
});
