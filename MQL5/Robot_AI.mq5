//+------------------------------------------------------------------+
//| Expert Advisor: EA_BB_RSI_BuySell_Display                       |
//| Logic: Auto BUY & SELL, tampilkan info lengkap di chart         |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

// === Input Parameters ===
input double LotSize       = 0.01;
input int    SLPoints      = 100;
input int    TPPoints      = 150;
input int    BBPeriod      = 20;
input double BBDeviation   = 2.0;
input int    RSIPeriod     = 14;
input double RSI_Buy_Max   = 40.0;
input double RSI_Sell_Min  = 60.0;

// === Indicator Handles ===
int bb_handle;
int rsi_handle;

// === Buffers ===
double upper[], middle[], lower[];
double rsiBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
    bb_handle = iBands(_Symbol, PERIOD_M30, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
    rsi_handle = iRSI(_Symbol, PERIOD_M30, RSIPeriod, PRICE_CLOSE);

    if (bb_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
    {
        Comment("❌ Gagal inisialisasi indikator.");
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
    // === Ambil nilai indikator ===
    if (CopyBuffer(bb_handle, 0, 0, 1, upper) <= 0 ||
        CopyBuffer(bb_handle, 2, 0, 1, lower) <= 0 ||
        CopyBuffer(rsi_handle, 0, 0, 1, rsiBuffer) <= 0)
    {
        Comment("❌ Gagal membaca indikator.");
        return;
    }

    // === Harga dan indikator ===
    double close    = iClose(_Symbol, PERIOD_M30, 0);
    double upperBB  = upper[0];
    double lowerBB  = lower[0];
    double rsi      = rsiBuffer[0];

    // === Info Akun ===
    double balance      = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity       = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin       = AccountInfoDouble(ACCOUNT_MARGIN);
    double freeMargin   = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    double profit       = AccountInfoDouble(ACCOUNT_PROFIT);

    // === String Tampilan Comment ===
    string info =
        "🔰 EA BB-RSI AUTO BUY/SELL\n" +
        "===============================\n" +
        "💰 Balance     : $" + DoubleToString(balance, 2) + "\n" +
        "📊 Equity      : $" + DoubleToString(equity, 2) + "\n" +
        "📈 Margin      : $" + DoubleToString(margin, 2) + "\n" +
        "💸 Free Margin : $" + DoubleToString(freeMargin, 2) + "\n" +
        "📈 Profit      : $" + DoubleToString(profit, 2) + "\n" +
        "===============================\n" +
        "⚙️ Input EA:\n" +
        "LotSize       = " + DoubleToString(LotSize, 2) + "\n" +
        "SL Points     = " + IntegerToString(SLPoints) + "\n" +
        "TP Points     = " + IntegerToString(TPPoints) + "\n" +
        "BB Period     = " + IntegerToString(BBPeriod) + "\n" +
        "BB Deviation  = " + DoubleToString(BBDeviation, 1) + "\n" +
        "RSI Period    = " + IntegerToString(RSIPeriod) + "\n" +
        "RSI Buy Max   = " + DoubleToString(RSI_Buy_Max, 1) + "\n" +
        "RSI Sell Min  = " + DoubleToString(RSI_Sell_Min, 1) + "\n" +
        "===============================\n" +
        "📍 Price       = " + DoubleToString(close, 2) + "\n" +
        "🔼 Upper BB    = " + DoubleToString(upperBB, 2) + "\n" +
        "🔽 Lower BB    = " + DoubleToString(lowerBB, 2) + "\n" +
        "📉 RSI         = " + DoubleToString(rsi, 2) + "\n";

    double sl, tp;

    // === Cek posisi ===
    if (PositionsTotal() > 0)
    {
        info += "⏳ Menunggu posisi tertutup...";
        Comment(info);
        return;
    }

    // === Kondisi BUY ===
    if (close <= lowerBB && rsi < RSI_Buy_Max)
    {
        sl = close - SLPoints * _Point;
        tp = close + TPPoints * _Point;
        if (trade.Buy(LotSize, _Symbol, close, sl, tp, "AutoBUY BB-RSI"))
            info += "✅ BUY OPENED @ " + DoubleToString(close, 2);
        else
            info += "❌ Gagal membuka BUY";
    }

    // === Kondisi SELL ===
    else if (close >= upperBB && rsi > RSI_Sell_Min)
    {
        sl = close + SLPoints * _Point;
        tp = close - TPPoints * _Point;
        if (trade.Sell(LotSize, _Symbol, close, sl, tp, "AutoSELL BB-RSI"))
            info += "✅ SELL OPENED @ " + DoubleToString(close, 2);
        else
            info += "❌ Gagal membuka SELL";
    }
    else
    {
        info += "🔍 Tidak ada sinyal entry.";
    }

    Comment(info);
}
