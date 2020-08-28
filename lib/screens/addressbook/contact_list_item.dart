import 'package:flutter/material.dart';
import 'package:komodo_dex/blocs/coins_bloc.dart';
import 'package:komodo_dex/blocs/dialog_bloc.dart';
import 'package:komodo_dex/model/addressbook_provider.dart';
import 'package:komodo_dex/model/coin.dart';
import 'package:komodo_dex/model/coin_balance.dart';
import 'package:komodo_dex/screens/addressbook/contact_edit.dart';
import 'package:komodo_dex/screens/portfolio/coin_detail/coin_detail.dart';
import 'package:komodo_dex/widgets/secondary_button.dart';
import 'package:provider/provider.dart';

class ContactListItem extends StatefulWidget {
  const ContactListItem(
    this.contact, {
    this.shouldPop = false,
    this.coin,
    this.expanded = false,
  });

  final Contact contact;
  final bool shouldPop;
  final Coin coin;
  final bool expanded;

  @override
  _ContactListItemState createState() => _ContactListItemState();
}

class _ContactListItemState extends State<ContactListItem> {
  bool expanded = false;
  AddressBookProvider addressBookProvider;

  @override
  void initState() {
    expanded = widget.expanded;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    addressBookProvider = Provider.of<AddressBookProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.contact.name,
              style: const TextStyle(
                fontSize: 20,
              ),
            ),
          ),
        ),
        if (expanded)
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Column(
              children: <Widget>[
                _buildAddressessList(),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FlatButton(
                        onPressed: () {
                          Navigator.push<dynamic>(
                              context,
                              MaterialPageRoute<dynamic>(
                                builder: (BuildContext context) => ContactEdit(
                                  contact: widget.contact,
                                ),
                              ));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.edit, size: 16),
                            const SizedBox(width: 4),
                            const Text('Edit'), // TODO(yurii): localization
                          ],
                        )),
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAddressessList() {
    final List<Widget> addresses = [];

    widget.contact.addresses?.forEach((String abbr, String value) {
      if (widget.coin != null) {
        String coinAbbr = widget.coin.abbr;
        if (widget.coin.type == 'erc') coinAbbr = 'ETH';
        if (widget.coin.type == 'smartChain') coinAbbr = 'KMD';

        if (coinAbbr != abbr) return;
      }

      addresses.add(
        Padding(
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                maxRadius: 6,
                backgroundImage: AssetImage('assets/${abbr.toLowerCase()}.png'),
              ),
              const SizedBox(width: 4),
              Text(
                '$abbr: ',
                style: const TextStyle(fontSize: 14),
              ),
              Flexible(
                child: InkWell(
                  onTap: () {
                    _tryToSend(abbr, value);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: _truncateMiddle(value),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).accentColor,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    if (addresses.isEmpty) {
      addresses.add(Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: <Widget>[
            Text(
              'Nothing found', // TODO(yurii): localization
              style: TextStyle(
                color: Theme.of(context).disabledColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ));
    }

    return Column(
      children: addresses,
    );
  }

  Widget _truncateMiddle(String string) {
    if (string.length < 6)
      return Text(
        string,
        style: TextStyle(
          color: Theme.of(context).accentColor,
          fontSize: 14,
        ),
      );

    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            string.substring(0, string.length - 5),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).accentColor,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          string.substring(string.length - 5),
          style: TextStyle(
            color: Theme.of(context).accentColor,
            fontSize: 14,
          ),
        )
      ],
    );
  }

  void _tryToSend(String abbr, String value) {
    final CoinBalance coinBalance = coinsBloc.coinBalance.firstWhere(
      (CoinBalance balance) {
        return balance.coin.abbr == abbr;
      },
      orElse: () => null,
    );
    if (widget.coin == null && coinBalance == null) {
      _showWarning(
        // TODO(yurii): localization
        title: 'No such coin',
        message: 'You can not send funds to $abbr address, '
            'because $abbr is not activated. Please go to portfolio.',
      );
      return;
    }

    addressBookProvider.clipboard = value;
    if (widget.shouldPop) {
      Navigator.of(context).pop();
    } else {
      Navigator.push<dynamic>(
          context,
          MaterialPageRoute<dynamic>(
            builder: (BuildContext context) => CoinDetail(
              coinBalance: coinBalance,
              isSendIsActive: true,
            ),
          ));
    }
  }

  void _showWarning({String title, String message}) {
    dialogBloc.dialog = showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          contentPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
            top: 10,
          ),
          title: Row(
            children: <Widget>[
              Icon(
                Icons.warning,
              ),
              const SizedBox(width: 12),
              Text(title),
            ],
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Flexible(
                    child: Text(
                  message,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    height: 1.4,
                  ),
                )),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SecondaryButton(
                onPressed: () {
                  dialogBloc.closeDialog(context);
                },
                child: const Text('OK'), // TODO(yurii): localization
              ),
            )
          ],
        );
      },
    );
  }
}