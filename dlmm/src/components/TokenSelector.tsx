import { useState } from "react";
import { ChevronDown, Wallet } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface Token {
  symbol: string;
  name: string;
  icon: string;
  balance: string;
}

interface TokenSelectorProps {
  selectedToken: Token;
  onTokenSelect: (token: Token) => void;
  tokens: Token[];
}

const TokenSelector = ({ selectedToken, onTokenSelect, tokens }: TokenSelectorProps) => {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="flex items-center gap-2 p-2 h-auto hover:bg-secondary">
          <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center text-primary-foreground text-xs font-bold">
            {selectedToken.icon}
          </div>
          <span className="font-medium text-foreground">{selectedToken.symbol}</span>
          <ChevronDown className="w-4 h-4 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-56 bg-popover border border-border">
        {tokens.map((token) => (
          <DropdownMenuItem 
            key={token.symbol}
            onClick={() => onTokenSelect(token)}
            className="flex items-center gap-3 p-3 cursor-pointer hover:bg-secondary"
          >
            <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-primary-foreground text-sm font-bold">
              {token.icon}
            </div>
            <div className="flex-1">
              <div className="font-medium text-foreground">{token.symbol}</div>
              <div className="text-sm text-muted-foreground">{token.name}</div>
            </div>
            <div className="text-right">
              <div className="text-sm text-muted-foreground flex items-center gap-1">
                <Wallet className="w-3 h-3" />
                {token.balance}
              </div>
            </div>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export default TokenSelector;