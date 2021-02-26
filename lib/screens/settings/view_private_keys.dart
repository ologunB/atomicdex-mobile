import 'package:flutter/material.dart';
import 'package:komodo_dex/blocs/coins_bloc.dart';
import 'package:komodo_dex/blocs/dialog_bloc.dart';
import 'package:komodo_dex/localizations.dart';
import 'package:komodo_dex/model/coin_balance.dart';
import 'package:komodo_dex/model/get_priv_key.dart';
import 'package:komodo_dex/model/priv_key.dart';
import 'package:komodo_dex/services/mm.dart';
import 'package:komodo_dex/utils/utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ViewPrivateKeys extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoinBalance>>(
      initialData: coinsBloc.coinBalance,
      stream: coinsBloc.outCoins,
      builder:
          (BuildContext context, AsyncSnapshot<List<CoinBalance>> snapshot) {
        if (!snapshot.hasData) return Container();
        final data = snapshot.data;
        data.sort((a, b) => a.coin.abbr.compareTo(b.coin.abbr));
        final zebra = <String, bool>{};
        bool zebraVal = false;
        for (CoinBalance cb in data) {
          zebra.putIfAbsent(cb.coin.abbr, () => zebraVal);
          zebraVal = !zebraVal;
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).privateKeys,
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 8.0,
              ),
              ...data.map(
                (cb) {
                  final coin = cb.coin.abbr;
                  return CoinPrivKey(
                    coin: coin,
                    zebra: zebra[coin] ?? false,
                  );
                },
              ).toList(),
            ],
          ),
        );
      },
    );
  }
}

class CoinPrivKey extends StatefulWidget {
  const CoinPrivKey({Key key, this.coin, this.zebra}) : super(key: key);

  final String coin;
  final bool zebra;

  @override
  _CoinPrivKeyState createState() => _CoinPrivKeyState();
}

class _CoinPrivKeyState extends State<CoinPrivKey> {
  BuildContext mContext;

  @override
  Widget build(BuildContext context) {
    setState(() => mContext = context);

    return Material(
        color: widget.zebra
            ? Theme.of(context).backgroundColor
            : Theme.of(context).cardColor,
        child: InkWell(
          onTap: () {
            dialogBloc.dialog = showDialog<dynamic>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  titlePadding: const EdgeInsets.all(0),
                  shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(6.0)),
                  content: _buildDialogContent(),
                );
              },
            ).then((dynamic data) {
              dialogBloc.dialog = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/${widget.coin.toLowerCase()}.png',
                          width: 32,
                          height: 32,
                        ),
                        SizedBox(
                          width: 8.0,
                        ),
                        Text(widget.coin),
                      ],
                    ),
                    Expanded(child: SizedBox()),
                    Icon(Icons.more_vert),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildDialogContent() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      width: MediaQuery.of(context).size.width * 0.9,
      child: FutureBuilder<PrivKey>(
          future: MM.getPrivKey(GetPrivKey(coin: widget.coin)),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(child: CircularProgressIndicator());

            final String privKey = snapshot.data.result.privKey;

            return Column(
              children: <Widget>[
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/${widget.coin.toLowerCase()}.png',
                      width: 16,
                      height: 16,
                    ),
                    SizedBox(
                      width: 4.0,
                    ),
                    Text(widget.coin),
                    SizedBox(
                      width: 6.0,
                    ),
                    Text(AppLocalizations.of(context).privateKey + ':')
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: QrImage(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    data: privKey,
                  ),
                ),
                SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    copyToClipBoard(mContext, privKey);
                    Future.delayed(Duration(seconds: 2), () {
                      Scaffold.of(mContext).hideCurrentSnackBar();
                    });
                  },
                  child: Text(privKey,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .copyWith(fontFamily: 'monospace')),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FlatButton(
                      child: Text(
                        AppLocalizations.of(context).close.toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .button
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            );
          }),
    );
  }
}