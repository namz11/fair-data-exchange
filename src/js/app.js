App = {
	web3Provider: null,
	contracts: {},
	currentAccount: '',

	init: async function () {
		return await App.initWeb3();
	},

	initWeb3: async function () {
		// TODO: refactor conditional
		if (typeof web3 !== 'undefined') {
			// If a web3 instance is already provided by Meta Mask.
			App.web3Provider = web3.currentProvider;
			web3 = new Web3(web3.currentProvider);
		} else {
			// Specify default instance if no web3 instance provided
			App.web3Provider = new Web3.providers.HttpProvider(
				'http://localhost:7545'
			);
			web3 = new Web3(App.web3Provider);
		}
		return App.initContract();
	},

	initContract: function () {
		$.getJSON('Verify.json', function (election) {
			// Instantiate a new truffle contract from the artifact
			App.contracts.Verify = TruffleContract(election);
			// Connect window.ethereum to interact with contract
			App.contracts.Verify.setProvider(App.web3Provider);

			App.listenForEvents();

			return App.render();
		});
	},

	// Listen for events emitted from the contract
	listenForEvents: function () {
		// TODO
		App.contracts.Verify.deployed().then(function (instance) {
			instance
				.BroadcastOrder(
					{},
					{
						fromBlock: 0,
						toBlock: 'pending',
					}
				)
				.watch(function (error, event) {
					alert(
						'Order is created. Please make the payment to receive the secret!'
					);
					console.log('BroadcastOrder', event);
				});
		});

		App.contracts.Verify.deployed().then(function (instance) {
			instance
				.BroadcastSecKey(
					{},
					{
						fromBlock: 0,
						toBlock: 'latest',
					}
				)
				.watch(function (error, event) {
					console.log('BroadcastSecKey', event);
				});
		});
	},

	render: function () {
		var loader = $('#loader');
		var msg = $('#msg');
		var content = $('#content');

		loader.show();
		msg.hide();
		content.hide();

		// Load contract data
		App.contracts.Verify.deployed()
			.then(function (instance) {
				verifyInstance = instance;
				return verifyInstance.dataCount();
			})
			.then(function (dataCount) {
				content.empty();
				var petTemplate = $('#petTemplate');

				for (var i = 1; i <= dataCount; i++) {
					verifyInstance.allData(i).then(function (data) {
						petTemplate.find('.panel-title').text(data[2]);
						petTemplate.find('img').attr('src', data[5]);
						petTemplate.find('.pet-age').text(`${+(data[3] / 1e18)} Eth`);

						petTemplate.find('.btn-download').attr('data-id', data[0]);
						petTemplate.find('.btn-download').attr('data-seller', data[1]);
						petTemplate.find('.btn-download').attr('data-url', data[4]);
						petTemplate.find('.btn-download').attr('data-price', data[3]);

						petTemplate.find('.btn-pay').attr('data-id', data[0]);
						petTemplate.find('.btn-pay').attr('data-seller', data[1]);
						petTemplate.find('.btn-pay').attr('data-price', data[3]);

						content.append(petTemplate.html());
					});
				}

				loader.hide();
				if (App.currentAccount == null || App.currentAccount?.trim() == '') {
					msg.show();
					content.hide();
				} else {
					msg.hide();
					content.show();
				}
			})
			.catch(function (error) {
				console.warn(error);
			});

		App.bindEvents();
	},

	bindEvents: function () {
		$(document).on('click', '.btn-download', App.handleDownload);
		$(document).on('click', '.btn-pay', App.handlePay);
		$(document).on('click', '.enableEthereumButton', App.getAccount);

		window.ethereum // Or window.ethereum if you don't support EIP-6963.
			.request({ method: 'eth_accounts' })
			.then(App.handleAccountsChanged)
			.catch((err) => {
				// Some unexpected error.
				// For backwards compatibility reasons, if no accounts are available, eth_accounts returns an
				// empty array.
				console.error(err);
			});

		// Note that this event is emitted on page load. If the array of accounts is non-empty, you're
		// already connected.
		window.ethereum // Or window.ethereum if you don't support EIP-6963.
			.on('accountsChanged', App.handleAccountsChanged);
	},

	handleDownload: function (event) {
		event.preventDefault();

		var id = parseInt($(event.target).data('id'));
		var url = $(event.target).data('url');
		var seller = $(event.target).data('seller');
		var price = parseInt($(event.target).data('price'));
		window.open(url, '_blank');

		App.contracts.Verify.deployed()
			.then(function (instance) {
				return instance.createPurchaseOrder(price, seller, {
					from: App.currentAccount,
				});
			})
			.then(function (result) {
				console.log('createPurchaseOrder', result);
			})
			.catch(function (err) {
				console.error(err);
			});
	},

	handlePay: function (event) {
		event.preventDefault();

		var id = parseInt($(event.target).data('id'));
		var seller = $(event.target).data('seller');
		var price = parseInt($(event.target).data('price'));

		App.contracts.Verify.deployed()
			.then(function (instance) {
				return instance.buyerLockPayment(seller, {
					from: App.currentAccount,
					value: price,
				});
			})
			.then(function (result) {
				console.log('buyerLockPayment', result);
				alert('Your secret key is ' + result.logs[0].args['_secKey']);
			})
			.catch(function (err) {
				console.error(err);
			});
	},

	// eth_accounts always returns an array.
	handleAccountsChanged: function (accounts) {
		if (accounts.length === 0) {
			// MetaMask is locked or the user has not connected any accounts.
			console.log('Please connect to MetaMask.');
		} else if (accounts[0] !== App.currentAccount) {
			// Reload your interface with accounts[0].
			App.currentAccount = accounts[0];
			// Update the account displayed (see the HTML for the connect button)
			$('#accountAddress').html('Your Account: ' + App.currentAccount);
		}
	},

	// While awaiting the call to eth_requestAccounts, you should disable any buttons the user can
	// select to initiate the request. MetaMask rejects any additional requests while the first is still
	// pending.
	getAccount: async function () {
		const accounts = await window.ethereum // Or window.ethereum if you don't support EIP-6963.
			.request({ method: 'eth_requestAccounts' })
			.catch((err) => {
				if (err.code === 4001) {
					// EIP-1193 userRejectedRequest error.
					// If this happens, the user rejected the connection request.
					console.log('Please connect to MetaMask.');
				} else {
					console.error(err);
				}
			});
		App.currentAccount = accounts[0];
		$('#accountAddress').html('Your Account: ' + App.currentAccount);
	},
};

$(function () {
	$(window).load(function () {
		App.init();
	});
});
